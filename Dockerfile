# Build container
ARG GOVERSION=1.15.3
FROM golang:$GOVERSION-alpine AS build

ARG VERSION=2020.10.2

ENV GO111MODULE=on \
    CGO_ENABLED=0

WORKDIR /src
RUN apk --no-cache add git build-base
RUN export
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .
RUN make cloudflared

# Runtime container
FROM alpine
WORKDIR /app

COPY --from=build /src/cloudflared .

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["./cloudflared", "--no-autoupdate"]
CMD ["version"]
