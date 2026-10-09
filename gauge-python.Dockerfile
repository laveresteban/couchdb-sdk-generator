# Python-capable Gauge runner for the conformance suite.
# Built on the (JS-only) couchdb-gauge-probe image; bakes in the Gauge plugins
# and the SDK's runtime deps so a run needs no setup.
FROM couchdb-gauge-probe:latest
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-pip \
 && rm -rf /var/lib/apt/lists/* \
 && ln -sf "$(command -v python3)" /usr/local/bin/python \
 && gauge install python \
 && gauge install html-report \
 && gauge install screenshot \
 && python3 -m pip install --break-system-packages --no-cache-dir \
      getgauge urllib3 python-dateutil "pydantic>=2" typing-extensions
COPY conformance-entrypoint.sh /usr/local/bin/run-conformance
RUN chmod +x /usr/local/bin/run-conformance
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/run-conformance"]
CMD []
