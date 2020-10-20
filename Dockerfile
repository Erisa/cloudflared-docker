FROM golang:1.15.3-alpine AS build

WORKDIR /go
RUN apk add git build-base
RUN go get github.com/cloudflare/cloudflared/cmd/cloudflared

FROM alpine
WORKDIR /app

COPY --from=build /go/bin/cloudflared .

ENV TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem
ENTRYPOINT ["./cloudflared", "--no-autoupdate"]
CMD ["version"]
