# Build container
ARG GOVERSION=1.25.6
ARG ALPINEVERSION=3.23
ARG GOHASH=98e6cffc31ccc44c7c15d83df1d69891efee8115a5bb7ede2bf30a38af3e3c92

FROM --platform=${BUILDPLATFORM} \
    golang@sha256:${GOHASH} AS build

WORKDIR /src
RUN apk --no-cache add git build-base bash

ENV GO111MODULE=on \
    CGO_ENABLED=0

ARG VERSION=master
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .

# From this point on, step(s) are duplicated per-architecture
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
# Fixes execution on linux/arm/v6 for devices that don't support armv7 binaries
RUN if [ "${TARGETVARIANT}" = "v6" ] && [ "${TARGETARCH}" = "arm" ]; then export GOARM=6; fi; \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} CONTAINER_BUILD=1 make LINK_FLAGS="-w -s" cloudflared 

# Runtime container
FROM scratch
WORKDIR /

COPY --from=build /src/cloudflared .
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENV NO_AUTOUPDATE=true
ENTRYPOINT ["/cloudflared", "--no-autoupdate"]
CMD ["version"]
