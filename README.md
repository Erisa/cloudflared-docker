# Erisa's Cloudflared Docker Image

This repository contains a simple Dockerfile to build `cloudflared`, the client for [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps), from [source](https://github.com/cloudflare/cloudflared).

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
| `linux/ppc64le` | `ppc64el`     | Tested on [IBM Cloud Power Systems Virtual Server](https://www.ibm.com/uk-en/products/power-virtual-server)

The public image corresponding to this Dockerfile is `erisamoe/cloudflared` and should work in mostly the same way as the [official image](https://hub.docker.com/r/cloudflare/cloudflared).

> **Note**  
> If you have any problems or questions with this image, either open a GitHub Issue or join the [Cloudflare Developers Discord Server](https://discord.gg/cloudflaredev) and ping `@Erisa#9999` in `#general` or `#off-topic` with your question.

## Cloudflare Tunnel

> **Warning**   
> Legacy Tunnels are becoming unsupported. You should migrate all existing legacy tunnels to Named Tunnels by October 1, 2022.

### Dashboard setup (Recommended)
A  `docker-compose` example with a Zero Trust dashboard setup would be:

``` yml
services:
  cloudflared:
    image: erisamoe/cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    depends_on:
      - mycontainer
```

Where `.env` contains `TUNNEL_TOKEN=` set to the token given by the Zero Trust dashboard.
For more information see [the Cloudflare Blog](https://blog.cloudflare.com/ridiculously-easy-to-use-tunnels/)

> **Note** A previous version of this README recommended using `--token ${CLOUDFLARED_TOKEN`, which is a less secure way of handing off the token. Setting the `TUNNEL_TOKEN` variable seems to be a better way of approaching this. 

### Config file setup (Named tunnel)
An example for a setup with a local config would be:
```yml
services:
  cloudflared:
    image: erisamoe/cloudflared
    restart: unless-stopped
    volumes:
      - ./cloudflared:/etc/cloudflared
    command: tunnel run mytunnel
    depends_on:
      - mycontainer
```

Where `./cloudflared` is a folder containing the `.json` or `.pem` credentials and `config.yml` for a tunnel.

An example `config.yml` might look like:
```yml
tunnel: uuid-for-tunnel
credentials-file: /etc/cloudflared/uuid-for-tunnel.json

ingress:
  - hostname: mywebsite.com
    service: http://nginx:80
  - service: http_status:404
```
For more information, refer to the [Cloudflare Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/#4-create-a-configuration-file)

To acquire a certificate, you'll need to use the `login` command.  
This will spit out `/.cloudflared/cert.pem`, rather than `/etc/cloudflared`.

As such, usage would be something like:  
```bash
docker run -v $PWD/cloudflared:/.cloudflared erisamoe/cloudflared login
```
to create a folder called `cloudflared` in your current dir and deposit a `cert.pem` into it.  

To create a tunnel, you can then do:
```bash
docker run -v $PWD/cloudflared:/.cloudflared erisamoe/cloudflared tunnel create mytunnel
```

Which gives you a UUID and `.json` credentials file for the tunnel.

And now you can either use the above compose example or for testing simply just:  
```bash
docker run -v $PWD/cloudflared:/etc/cloudflared erisamoe/cloudflared --hostname test.example.com --name mytunnel --hello-world
```
Which will start up a "Hello world" test tunnel on `https://test.example.com`.

## DNS-over-HTTPS
While not the original intent behind the image, you can also use this to host a DNS resolver that speaks to a DNS-over-HTTPS backend.  
For example:
```
docker run -d -p 53:53/udp --name my-dns-forwarder erisamoe/cloudflared proxy-dns
```
Would create a container called `my-dns-forwarder` that responds to DNS requests on your host.  
Keep in mind when using this on a public server (e.g. VPS) it will by default listen on all interfaces, making you a public DNS resolver on the internet.  
You can sidestep this by changing the `-p` to instead be `-p 127.0.0.01:53:53/udp` to listen on localhost instead.

You can also add upstreams with `--upstream https://dns.example.com` for example. By default, Cloudflare DNS is used.
