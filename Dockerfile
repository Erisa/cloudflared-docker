# Build container
ARG GOVERSION=1.20.12
ARG ALPINEVERSION=3.19

FROM --platform=${BUILDPLATFORM} \
    golang:$GOVERSION-alpine${ALPINEVERSION} AS build

WORKDIR /src
RUN apk --no-cache add git build-base bash

ENV GO111MODULE=on \
    CGO_ENABLED=0

ARG VERSION=2024.1.2
RUN git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .
ARG TARGETOS
ARG TARGETARCH
RUN bash -x .teamcity/install-cloudflare-go.sh
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make cloudflared

# Runtime container
FROM scratch
WORKDIR /

COPY --from=build /src/cloudflared .
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["/cloudflared", "--no-autoupdate"]
CMD ["version"]
