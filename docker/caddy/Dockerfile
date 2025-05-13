FROM caddy:2.10.0-builder AS builder

RUN xcaddy build \
  # --with github.com/hslatman/caddy-crowdsec-bouncer:v0.8.1 \
  --with github.com/lucaslorentz/caddy-docker-proxy/v2:v2.9.2 \
  --with github.com/caddy-dns/cloudflare

FROM caddy:2.10.0

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]
