#!/bin/sh
set -eu

if [ "${1:-}" = --check-image ]; then
    if ! grep -Eq '^config-version:[[:blank:]]+8[[:blank:]]*(#.*)?$' /CLIProxyAPI/config.example.yaml; then
        printf '%s\n' 'CLIPROXY_IMAGE must support the v8 configuration format. Select a compatible image.' >&2
        exit 1
    fi
    exit 0
fi

public_urls=${COOLIFY_URL:-}
case "$public_urls" in
    '')
        if [ -n "${COOLIFY_RESOURCE_UUID:-}" ]; then
            printf '%s\n' 'No HTTPS domain is assigned to CLIProxyAPI in Coolify.' >&2
            exit 1
        fi
        ;;
    http://*|*,http://*)
        printf '%s\n' 'CLIProxyAPI requires HTTPS for every public route. Replace any HTTP domain in Coolify.' >&2
        exit 1
        ;;
    https://?*) ;;
    *)
        printf '%s\n' 'CLIProxyAPI requires an HTTPS public URL.' >&2
        exit 1
        ;;
esac

umask 077
config=/data/config.yaml

validate_key() {
    case "$2" in
        ''|*[!A-Za-z0-9_-]*)
            printf '%s must use letters, digits, underscores or hyphens.\n' "$1" >&2
            exit 1
            ;;
    esac
    if [ "${#2}" -lt 32 ]; then
        printf '%s must be at least 32 characters.\n' "$1" >&2
        exit 1
    fi
}

MANAGEMENT_PASSWORD=${MANAGEMENT_PASSWORD:-${SERVICE_PASSWORD_64_CLIPROXYMANAGEMENT:-}}
validate_key CLIPROXY_MANAGEMENT_KEY "$MANAGEMENT_PASSWORD"
export MANAGEMENT_PASSWORD
mkdir -p /data/auth

if [ ! -e "$config" ]; then
    CLIPROXY_API_KEY=${CLIPROXY_API_KEY:-${SERVICE_PASSWORD_64_CLIPROXYAPI:-}}
    if [ -z "$CLIPROXY_API_KEY" ]; then
        printf '%s\n' 'CLIPROXY_API_KEY is required when initializing a new data volume.' >&2
        exit 1
    fi
    validate_key CLIPROXY_API_KEY "$CLIPROXY_API_KEY"
    if [ "$CLIPROXY_API_KEY" = "$MANAGEMENT_PASSWORD" ]; then
        printf '%s\n' 'Use different API and management keys.' >&2
        exit 1
    fi

    tmp=$(mktemp /data/config.XXXXXX)
    trap 'rm -f "$tmp"' EXIT
    trap 'exit 1' HUP INT TERM
    cat > "$tmp" <<EOF
config-version: 8
server:
  host: "0.0.0.0"
  port: 8317
management:
  allow-remote: true
access:
  api-keys:
    - "$CLIPROXY_API_KEY"
oauth:
  auth-dir: "/data/auth"
routing:
  strategy: "round-robin"
  session-affinity: true
  session-affinity-ttl: "1h"
  retry:
    request-retry: 3
    max-retry-interval: 30
requests:
  streaming:
    keepalive-seconds: 15
EOF
    mv "$tmp" "$config"
    trap - EXIT HUP INT TERM
fi

exec "$@"
