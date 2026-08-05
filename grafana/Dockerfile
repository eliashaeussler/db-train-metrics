FROM grafana/grafana-oss:latest

COPY ./dashboards/train-data.json /etc/grafana/dashboards/train-data.template.json

USER root
RUN set -eux; \
    apk add jq; \
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"; \
    jq --arg from "$NOW" \
        '.time.from = $from' \
        /etc/grafana/dashboards/train-data.template.json \
        > /etc/grafana/dashboards/train-data.json; \
    rm /etc/grafana/dashboards/train-data.template.json
USER grafana
