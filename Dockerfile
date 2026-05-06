FROM python:3.13.13-slim

WORKDIR /apisec

RUN useradd --create-home --uid 10001 apisec \
 && chown apisec:apisec /apisec

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
 && pip install --no-cache-dir requests python-dotenv

COPY --chown=apisec:apisec __init__.py colors.py main.py models.py scanner.py table.py utils.py ./

USER apisec

RUN chmod +x ./main.py

CMD ["./main.py"]
