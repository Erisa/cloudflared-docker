variable "CLOUDFLARED_VERSION" {
    default = "2026.1.2"
}

variable "LATEST" {
    default = true
}

variable "MULTI_PLATFORM" {
    default = false
}

variable "GOVERSION" {
    default = "1.25.6"
}

variable "ALPINEVERSION" {
    default = "3.23"
}

variable "GOHASH" {
    default = "98e6cffc31ccc44c7c15d83df1d69891efee8115a5bb7ede2bf30a38af3e3c92"
}

target "default" {
    args = {
        VERSION = CLOUDFLARED_VERSION
        GOVERSION = GOVERSION
        ALPINEVERSION = ALPINEVERSION
        GOHASH = GOHASH
    }
    platforms = !MULTI_PLATFORM ? null : [
        "linux/amd64",
        "linux/386",
        "linux/arm64",
        "linux/arm/v7",
        "linux/arm/v6",
        "linux/s390x",
        "linux/ppc64le",
        "linux/riscv64"
    ]
    tags = [
        "erisamoe/cloudflared:${CLOUDFLARED_VERSION}",
        "ghcr.io/erisa/cloudflared:${CLOUDFLARED_VERSION}",
        LATEST ? "erisamoe/cloudflared:latest" : "",
        LATEST ? "ghcr.io/erisa/cloudflared:latest" : "",
    ]
}
