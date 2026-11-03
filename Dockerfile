FROM node:24-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pin the version: `npm view @deepseek-ai/dsh version`.
# Use 0.2.1-rc.2 or newer (older builds hid model settings behind a proxy, see upstream #9541).
ARG DSH_VERSION=0.2.1-rc.5
RUN npm i -g "@deepseek-ai/dsh@${DSH_VERSION}" && npm cache clean --force

ENV DSH_HOME=/data/dsh
WORKDIR /workspace

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3080

# Any HTTP answer (401 without a token is normal) means the server is up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://'+(process.env.DSH_HOST||require('os').networkInterfaces().eth0?.find(i=>i.family==='IPv4')?.address)+':3080/').then(r=>process.exit(r.status<500?0:1),()=>process.exit(1))"

ENTRYPOINT ["/entrypoint.sh"]
