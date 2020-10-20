# Erisa's Coudflared Docker Image

This repository contains a simple Dockerfile to build `cloudflared`, the client for Cloudflare's [Argo Tunnel](https://developers.cloudflare.com/argo-tunnel/), from [source](https://github.com/cloudflare/cloudflared).

The aim is to support multiple architectures.  
The public image currently supports:
| Docker target  | Also known as | Notes                                                                                                     |
|----------------|---------------|-----------------------------------------------------------------------------------------------------------|
| `linux/amd64`  | `x86_64`      | Majority of modern PCs and servers.                                                                       |
| `linux/arm64`  | `aarch64`     | 64-bit ARM hardware. For example Raspberry Pi 2/3/4 running a 64-bit OS.                                  |
| `linux/arm/v7` | `armhf`       | 32-bit ARM hardware. For example most Raspberry Pi models running Raspberry Pi OS.                        |
| `linux/arm/v6` | `armel`       | Older 32-bit ARM hardware. Mostly Raspberry Pi 1/0/0W but there may be others. These images are untested. |


The public image corresponding to this Dockerfile is `erisamoe/cloudflared` and should work in mostly the same way as the [official image](https://hub.docker.com/r/cloudflare/cloudflared)

A basic `docker-compose` example for exposing an internal service would be:
```yml
    cloudflared:
        image: erisamoe/cloudflared
        container_name: cloudflared
        volumes:
            - ./cloudflared:/etc/cloudflared
        command: --hostname mycontainer.example.com --url http://mycontainer:8080
        depends_on:
            - mycontainer
```
With `./cloudflared` being a directory containing the certifcate for Argo Tunnel. For more details on `cloudflared` usage, check out the [official docs](https://developers.cloudflare.com/argo-tunnel/)
