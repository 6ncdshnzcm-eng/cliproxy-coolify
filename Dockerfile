ARG CLIPROXY_IMAGE=eceasy/cli-proxy-api:latest
FROM ${CLIPROXY_IMAGE}

COPY docker-entrypoint.sh /usr/local/bin/cliproxy-start

RUN chmod 755 /usr/local/bin/cliproxy-start \
    && /usr/local/bin/cliproxy-start --check-image \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl tzdata \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/cliproxy-start"]
CMD ["/CLIProxyAPI/CLIProxyAPI", "-config", "/data/config.yaml"]
