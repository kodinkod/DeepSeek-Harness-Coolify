#!/bin/sh
set -e

: "${PUBLIC_URL:?PUBLIC_URL is required, e.g. https://dsh.example.com/}"
: "${TRUSTED_HOST:?TRUSTED_HOST is required, e.g. dsh.example.com}"

# dsh rejects wildcard binds (0.0.0.0), so bind the container's own address.
# Override with DSH_HOST if the container sits on several networks.
HOST="${DSH_HOST:-$(hostname -i | awk '{print $1}')}"

exec dsh --profile web --no-open \
  --host "$HOST" \
  --port 3080 \
  --public-url "$PUBLIC_URL" \
  --trusted-host "$TRUSTED_HOST"
