# apisec-cicd-latest-fetch

CI/CD gate that reads the **current detection state** of an APIsec
application/instance and applies CVSS-severity / error-count thresholds —
without triggering a new scan. Pairs with the APIsec scanner image for the
"scan-on-schedule, gate-on-PR" pattern, where PRs gate against the latest
known findings instead of paying the 10–30 minute cost of a fresh scan on
every push.

## Quick start (GitHub Actions)

The recommended consumption pattern is the composite Action — clean
`with:` inputs, the version pin lives on the `@vX.Y.Z` ref, and GitHub
handles the docker pull and exit-code propagation for you.

```yaml
name: APIsec Latest Scan Gate
on:
  pull_request:
  push:
    branches: [main]

jobs:
  apisec-gate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: Gavin-Hensley/apisec-cicd-latest-fetch@v0.2.3
        with:
          application_id: ${{ secrets.APISEC_APPLICATION_ID }}
          instance_id: ${{ secrets.APISEC_INSTANCE_ID }}
          access_token: ${{ secrets.APISEC_ACCESS_TOKEN }}
          fail_on_severity_threshold: '8'
          fail_on_error_threshold: '0'
          print_summary: 'true'
```

The image is published for `linux/amd64`, which matches GitHub's
`ubuntu-latest` runners — no QEMU emulation required.

### Alternative consumption patterns

If you'd rather not pin to a Git ref, two equivalent options:

```yaml
# Pull the published image directly
- uses: docker://gavinapisec/apisec-cicd-latest-fetch:0.2.3
  env:
    INPUT_APPLICATION_ID: ${{ secrets.APISEC_APPLICATION_ID }}
    INPUT_INSTANCE_ID: ${{ secrets.APISEC_INSTANCE_ID }}
    INPUT_ACCESS_TOKEN: ${{ secrets.APISEC_ACCESS_TOKEN }}
    INPUT_FAIL_ON_SEVERITY_THRESHOLD: '8'
    INPUT_FAIL_ON_ERROR_THRESHOLD: '0'
    INPUT_PRINT_SUMMARY: 'true'
```

```yaml
# Plain docker run
- name: Run APIsec gate
  env:
    APISEC_APPLICATION_ID: ${{ secrets.APISEC_APPLICATION_ID }}
    APISEC_INSTANCE_ID: ${{ secrets.APISEC_INSTANCE_ID }}
    APISEC_ACCESS_TOKEN: ${{ secrets.APISEC_ACCESS_TOKEN }}
  run: |
    docker run --rm \
      -e INPUT_APPLICATION_ID="$APISEC_APPLICATION_ID" \
      -e INPUT_INSTANCE_ID="$APISEC_INSTANCE_ID" \
      -e INPUT_ACCESS_TOKEN="$APISEC_ACCESS_TOKEN" \
      -e INPUT_FAIL_ON_SEVERITY_THRESHOLD=8 \
      -e INPUT_FAIL_ON_ERROR_THRESHOLD=0 \
      -e INPUT_PRINT_SUMMARY=true \
      gavinapisec/apisec-cicd-latest-fetch:0.2.3
```

## Inputs (env vars)

| Variable | Required | Default | Description |
|---|---|---|---|
| `INPUT_APPLICATION_ID` | yes | — | APIsec application id |
| `INPUT_INSTANCE_ID` | yes | — | APIsec instance id |
| `INPUT_ACCESS_TOKEN` | yes | — | APIsec bearer token |
| `INPUT_APISEC_BASE_URL` | no | `https://api.apisecapps.com` | https-only |
| `INPUT_FAIL_ON_SEVERITY_THRESHOLD` | no | unbounded | CVSS floor — findings ≥ this score count as errors |
| `INPUT_FAIL_ON_ERROR_THRESHOLD` | no | unbounded | Max acceptable errors before the gate fails |
| `INPUT_PRINT_SUMMARY` | no | `false` | Print severity / score count tables |
| `INPUT_PRINT_FULL` | no | `false` | Print one row per finding |

## Behaviour

1. `GET /v1/applications/{appId}/instances/{instanceId}/detections?include=metadata&slim=true`
2. Filter to `status == "ACTIVE"` — findings marked `DISMISSED`,
   `RISK_ACCEPTED`, or `RESOLVED` appear in the API response but do **not**
   count toward the gate.
3. Count active findings whose `cvssScore` ≥ `FAIL_ON_SEVERITY_THRESHOLD`.
4. If that count > `FAIL_ON_ERROR_THRESHOLD` → exit `1`. Otherwise exit `0`.

### Defensive pagination + truncation warning

The `/detections` endpoint is not documented as paginated, but the image
defends against silent server-side truncation in two ways:

- If a top-level `nextToken` ever appears in the response, the image walks
  it (capped at 100 pages).
- After merging all pages, `metadata.totalActiveVulnerabilities` is
  compared to the count of ACTIVE findings actually received. If the API
  reports more than we got, a yellow warning prints naming both numbers —
  the gate still runs against what was received, but the discrepancy
  surfaces in CI logs.

## Exit codes

| Exit | Reason |
|---|---|
| `0` | No ACTIVE findings exceed the gate |
| `1` | Gate failed, OR `GET /detections` returned non-2xx (auth, 404, 5xx exhausted) |

## Versioning

Tag-driven. Pushing a git tag `vX.Y.Z` builds and publishes the image to
Docker Hub as `gavinapisec/apisec-cicd-latest-fetch:X.Y.Z` and (for stable
tags without a `-` suffix) `:latest`.

## Local development

```bash
# Build the image
docker build -t apisec-cicd-latest-fetch:dev .

# Run the in-container test suite
docker run --rm \
  -v "$PWD/tests:/test:ro" \
  --workdir /apisec --entrypoint sh \
  apisec-cicd-latest-fetch:dev \
  -c 'python3 /test/test_robustness.py'
```

24 in-process robustness tests cover the detections shape, ACTIVE-only
filtering, `nextToken` pagination, truncation detection, and HTTP error
paths.

## License

MIT — see [LICENSE](LICENSE).
