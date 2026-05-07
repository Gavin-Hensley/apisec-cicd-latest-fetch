FROM python:3.13.13-slim

WORKDIR /apisec

RUN useradd --create-home --uid 10001 apisec \
 && chown apisec:apisec /apisec

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
 && pip install --no-cache-dir requests python-dotenv

COPY --chown=apisec:apisec __init__.py colors.py main.py models.py scanner.py table.py utils.py ./

USER apisec

RUN chmod +x ./main.py

# Absolute path matters when this image runs as a GitHub Actions Docker
# action — Actions overrides WORKDIR to /github/workspace, which would
# break a relative "./main.py" reference. ENTRYPOINT (not CMD) so that
# Actions' optional `args:` are appended as script args, not replaced.
ENTRYPOINT ["python3", "/apisec/main.py"]
