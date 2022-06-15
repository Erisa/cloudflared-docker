# Build container
ARG GOVERSION=1.18.3
ARG ALPINEVERSION=3.16

FROM --platform=${BUILDPLATFORM} \
    golang:$GOVERSION-alpine${ALPINEVERSION} AS build

WORKDIR /src
RUN apk --no-cache add git build-base

ENV GO111MODULE=on \
    CGO_ENABLED=0

ARG VERSION=f2339a72445ec1e0b5e5c49d3e0b42a6b6930a33
RUN git clone https://github.com/cloudflare/cloudflared .
RUN git checkout ${VERSION}
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
