# Stage 1: 构建阶段 - 用官方golang镜像下载并编译 gost
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git

# 下载 gost v2.11.1（或你想要的版本）
RUN git clone --depth=1 --branch v2.11.1 https://github.com/ginuerzh/gost.git /src

WORKDIR /src
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o gost main.go

# Stage 2: 生产阶段 - 极简alpine镜像
FROM alpine:3.17

RUN apk add --no-cache curl ca-certificates iproute2 iptables wireguard-tools openresolv

# 复制编译好的 gost
COPY --from=builder /src/gost /usr/local/bin/gost
RUN chmod +x /usr/local/bin/gost

# 复制 warp 优选工具（请自行提前准备好对应 arm64 的 warp 文件放到上下文）
COPY warp-arm64 /usr/local/bin/warp
RUN chmod +x /usr/local/bin/warp

WORKDIR /wgcf
COPY entry.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
