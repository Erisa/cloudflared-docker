variable "CLOUDFLARED_VERSION" {
    default = "2025.11.1"
}

variable "LATEST" {
    default = true
}

variable "MULTI_PLATFORM" {
    default = false
}

variable "GOVERSION" {
    default = "1.24.7"
}

variable "ALPINEVERSION" {
    default = "3.22"
}

target "default" {
    args = {
        VERSION = CLOUDFLARED_VERSION
        GOVERSION = GOVERSION
        ALPINEVERSION = ALPINEVERSION
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
