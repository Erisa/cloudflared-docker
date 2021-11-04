# Build container
ARG GOVERSION=1.17.3
FROM --platform=${BUILDPLATFORM} \
    golang:$GOVERSION-alpine AS build

WORKDIR /src
RUN apk --no-cache add git build-base

ENV GO111MODULE=on \
    CGO_ENABLED=0

ARG VERSION=2021.11.0
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .
ARG TARGETOS
ARG TARGETARCH
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make cloudflared

# Runtime container
FROM scratch
WORKDIR /

COPY --from=build /src/cloudflared .
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["/cloudflared", "--no-autoupdate"]
CMD ["version"]
