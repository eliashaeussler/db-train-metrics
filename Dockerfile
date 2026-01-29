FROM python:3-slim

RUN mkdir -p /app
WORKDIR /app

COPY requirements.txt /app
RUN pip install --no-cache-dir -r requirements.txt

COPY lib/metrics_exporter.py /app

EXPOSE 8080
ENTRYPOINT ["python", "./metrics_exporter.py"]
