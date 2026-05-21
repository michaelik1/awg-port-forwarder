FROM amneziavpn/amneziawg-go:latest
LABEL authors="michaelik1"

WORKDIR /workdir

RUN apk add --no-cache socat
