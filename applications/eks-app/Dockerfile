FROM python:3.13.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

RUN addgroup --system --gid 10001 notes \
    && adduser --system --uid 10001 --ingroup notes --home /app notes

COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

COPY app.py ./app.py
COPY templates ./templates
COPY static ./static

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]

CMD ["gunicorn", "--bind=0.0.0.0:8080", "--workers=2", "--threads=4", "--timeout=30", "app:app"]
