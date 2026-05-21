FROM amneziavpn/amneziawg-go:latest
LABEL authors="michaelik"

WORKDIR /workdir

RUN apk add --no-cache socat
