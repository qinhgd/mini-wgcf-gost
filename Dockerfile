FROM alpine:3.17

RUN apk add --no-cache \
    curl ca-certificates iproute2 iptables \
    wireguard-tools openresolv tar gzip \
 && rm -rf /var/cache/apk/*

COPY gost /usr/local/bin/gost
RUN chmod +x /usr/local/bin/gost

COPY warp-arm64 /usr/local/bin/warp
RUN chmod +x /usr/local/bin/warp

WORKDIR /wgcf
COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
