# Stage 1: Build container
# Use a specific Golang version and Alpine Linux as the base image
ARG GOVERSION=1.20.12
ARG ALPINEVERSION=3.19

FROM --platform=${BUILDPLATFORM} \
    golang:$GOVERSION-alpine${ALPINEVERSION} AS build

# Set the working directory for the build
WORKDIR /src

# Install necessary dependencies for building
RUN apk --no-cache -U add git build-base curl jq

# Fetch the latest release version using GitHub API
RUN VERSION=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | jq -r .tag_name) \
    && git clone https://github.com/cloudflare/cloudflared --depth=1 --branch ${VERSION} .

# Build the cloudflared binary for Linux amd64
ARG TARGETOS
ARG TARGETARCH
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make cloudflared

# Stage 2: Runtime container
FROM scratch

# Copy the built cloudflared binary and required files
COPY --from=build /src/cloudflared .
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Set environment variable for the cloudflared origin certificate
ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["/cloudflared", "--no-autoupdate"]
CMD ["version"]