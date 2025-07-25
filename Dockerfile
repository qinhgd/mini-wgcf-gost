FROM alpine:3.17

# 安装基本依赖
RUN apk update && apk --no-cache add \
    curl ca-certificates iproute2 iptables \
    wireguard-tools openresolv tar gzip \
    && rm -rf /var/cache/apk/*

# 安装 GOST 2.x (UDP 支持)
COPY gost_2.11.1_linux_arm64.gz /tmp/gost.gz
RUN cd /tmp && \
    gunzip gost.gz && chmod +x gost && \
    mv gost /usr/local/bin/gost && \
    rm -rf /tmp/*

# 安装 WARP 优选工具（本地预置）
COPY warp-arm64 /usr/local/bin/warp
RUN chmod +x /usr/local/bin/warp

# 设置工作目录与入口脚本
WORKDIR /wgcf
COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
