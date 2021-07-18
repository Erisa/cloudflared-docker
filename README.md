# Erisa's Cloudflared Docker Image

This repository contains a simple Dockerfile to build `cloudflared`, the client for Cloudflare's [Argo Tunnel](https://developers.cloudflare.com/argo-tunnel/), from [source](https://github.com/cloudflare/cloudflared).

The aim is to support multiple architectures.  
The public image currently supports:
| Docker target  | Also known as | Notes                                                                                                         |
|----------------|---------------|---------------------------------------------------------------------------------------------------------------|
| `linux/amd64`  | `x86_64`      | Majority of modern PCs and servers.                                                                           |
| `linux/386`    | `x86`         | 32-bit Intel/AMD CPUs. Typically really old computer hardware. These images are **untested**.                 |
| `linux/arm64`  | `aarch64`     | 64-bit ARM hardware. For example Apple Silicon or Raspberry Pi 2/3/4 running a 64-bit OS.                     |
| `linux/arm/v7` | `armhf`       | 32-bit ARM hardware. For example most Raspberry Pi models running Raspberry Pi OS.                            |
| `linux/arm/v6` | `armel`       | Older 32-bit ARM hardware. Mostly Raspberry Pi 1/0/0W but there may be others. These images are **untested**. |
| `linux/s390x`  | `IBM Z`       | [Linux on IBM Z](https://en.wikipedia.org/wiki/Linux_on_IBM_Z) for IBM mainframes, most notably [IBM Cloud](https://www.ibm.com/uk-en/cloud). |

The public image corresponding to this Dockerfile is `erisamoe/cloudflared` and should work in mostly the same way as the [official image](https://hub.docker.com/r/cloudflare/cloudflared).

### Cloudflare Tunnel (formerly Argo Tunnel) 
A basic `docker-compose` example for exposing an internal service would be:

``` yml
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

To acquire a certificate, you'll need to use the `login` command.  
This will spit out `/.cloudflared/cert.pem`, rather than `/etc/cloudflared`.

As such, usage would be something like:  
```bash
docker run -v $PWD/cloudflared:/.cloudflared erisamoe/cloudflared login
```
to create a folder called `cloudflared` in your current dir and deposit a `cert.pem` into it.  

And now you can either use the above compose example or for testing simply just:  
```bash
docker run -v $PWD/cloudflared:/etc/cloudflared erisamoe/cloudflared --hostname test.example.com --hello-world
```
Which will start up a "Hello world" test tunnel on `https://test.example.com`.

### DNS-over-HTTPS
While not the original intent behind the image, you can also use this to host a DNS resolver that speaks to a DNS-over-HTTPS backend.  
For example:
```
docker run -d -p 53:53/udp --name my-dns-forwarder erisamoe/cloudflared proxy-dns
```
Would create a container called `my-dns-forwarder` that responds to DNS requests on your host.  
Keep in mind when using this on a public server (e.g. VPS) it will by default listen on all interfaces, making you a public DNS resolver on the internet.  
You can sidestep this by changing the `-p` to instead be `-p 127.0.0.01:53:53/udp` to listen on localhost instead.

You can also add upstreams with `--upstream https://dns.example.com` for example. By default, Cloudflare DNS is used.
