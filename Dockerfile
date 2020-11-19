# Build container
ARG GOVERSION=1.15.5
FROM golang:$GOVERSION-alpine AS build

ARG VERSION=2020.11.9

ENV GO111MODULE=on \
    CGO_ENABLED=0

WORKDIR /src
RUN apk --no-cache add git build-base
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .
RUN make cloudflared

# Runtime container
FROM scratch
WORKDIR /

COPY --from=build /src/cloudflared .
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["/cloudflared", "--no-autoupdate"]
CMD ["version"]
