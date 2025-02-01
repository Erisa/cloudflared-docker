# Build container
ARG GOVERSION=1.22.10
ARG ALPINEVERSION=3.21

FROM --platform=${BUILDPLATFORM} \
    golang:$GOVERSION-alpine${ALPINEVERSION} AS build

WORKDIR /src
RUN apk --no-cache add git build-base bash

ENV GO111MODULE=on \
    CGO_ENABLED=0

ARG VERSION=2025.1.1
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .
RUN bash -x .teamcity/install-cloudflare-go.sh

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
