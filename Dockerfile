FROM alpine:3.17

RUN apk add --no-cache \
    curl ca-certificates iproute2 iptables \
    wireguard-tools openresolv tar gzip \
 && rm -rf /var/cache/apk/*

# 合并 gzip 解压与清理操作为同一层，避免额外层大小
COPY gost_2.11.1_linux_arm64.gz /tmp/gost.gz
RUN gunzip -c /tmp/gost.gz > /usr/local/bin/gost && \
    chmod +x /usr/local/bin/gost && \
    rm -f /tmp/gost.gz

COPY warp-arm64 /usr/local/bin/warp
RUN chmod +x /usr/local/bin/warp

WORKDIR /wgcf
COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
