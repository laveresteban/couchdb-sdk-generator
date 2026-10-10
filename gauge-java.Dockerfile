# JVM Gauge runner for couchdb-android's conformance module (see docker-compose.yml).
# The Android SDK isn't needed: the conformance steps only use sync-core.
FROM eclipse-temurin:17-jdk
ARG GAUGE_VERSION=1.6.38
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/gauge.zip \
      "https://github.com/getgauge/gauge/releases/download/v${GAUGE_VERSION}/gauge-${GAUGE_VERSION}-linux.x86_64.zip" \
 && unzip -q /tmp/gauge.zip -d /usr/local/bin && rm /tmp/gauge.zip \
 && gauge install java \
 && gauge install html-report
ENV ANDROID_HOME=""
WORKDIR /sdk
