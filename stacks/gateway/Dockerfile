ARG CADDY_VERSION=2
FROM caddy:${CADDY_VERSION}-builder AS builder

# no need the "v2.9.0-beta.2" part after new version release
RUN xcaddy build v2.9.0-beta.2 \ 
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    --with github.com/caddy-dns/cloudflare

FROM caddy:${CADDY_VERSION}-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

CMD ["caddy", "docker-proxy"]
