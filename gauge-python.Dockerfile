# Python Gauge runner for the conformance suite (see docker-compose.yml).
# Gauge comes from its GitHub release; no Node needed.
# Plugins and the SDK's runtime deps are baked in so a run needs no setup.
FROM python:3.12-slim
ARG GAUGE_VERSION=1.6.38
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/gauge.zip \
      "https://github.com/getgauge/gauge/releases/download/v${GAUGE_VERSION}/gauge-${GAUGE_VERSION}-linux.x86_64.zip" \
 && unzip -q /tmp/gauge.zip -d /usr/local/bin && rm /tmp/gauge.zip \
 && gauge install python \
 && gauge install html-report \
 && pip install --no-cache-dir getgauge urllib3 python-dateutil "pydantic>=2" typing-extensions
COPY conformance-entrypoint.sh /usr/local/bin/run-conformance
RUN chmod +x /usr/local/bin/run-conformance
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-conformance"]
CMD []
