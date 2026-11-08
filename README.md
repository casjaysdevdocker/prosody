## 👋 Welcome to prosody 🚀  

prosody README  
  
  
## Install my system scripts  

```shell
 sudo bash -c "$(curl -q -LSsf "https://github.com/systemmgr/installer/raw/main/install.sh")"
 sudo systemmgr --config && sudo systemmgr install scripts  
```
  
## Automatic install/update  
  
```shell
dockermgr update prosody
```
  
## Install and run container
  
```shell
dockerHome="/srv/$USER/docker/casjaysdevdocker/prosody/prosody/latest/volumes"
mkdir -p "/srv/$USER/docker/prosody/volumes"
git clone "https://github.com/dockermgr/prosody" "$HOME/.local/share/CasjaysDev/dockermgr/prosody"
cp -Rfva "$HOME/.local/share/CasjaysDev/dockermgr/prosody/volumes/." "$dockerHome/"
docker run -d \
--restart always \
--privileged \
--name casjaysdevdocker-prosody-latest \
--hostname prosody \
-e TZ=${TIMEZONE:-America/New_York} \
-v "$dockerHome/data:/data:z" \
-v "$dockerHome/config:/config:z" \
-p 80:80 \
casjaysdevdocker/prosody:latest
```
  
## via docker-compose  
  
```yaml
# nginx proxy address - http://172.17.0.1:5280
name: prosody

x-logging: &logging
  driver: json-file
  options:
    max-size: 10m
    max-file: "3"

services:
  prosody:
    image: ghcr.io/casjaysdevdocker/prosody:latest
    pull_policy: always
    restart: always
    logging: *logging
    environment:
      XMPP_DOMAIN: meet.jitsi
      XMPP_AUTH_DOMAIN: auth.meet.jitsi
      XMPP_GUEST_DOMAIN: guest.meet.jitsi
      XMPP_MUC_DOMAIN: muc.meet.jitsi
      XMPP_INTERNAL_MUC_DOMAIN: internal-muc.meet.jitsi
      XMPP_HIDDEN_DOMAIN: hidden.meet.jitsi
      JICOFO_AUTH_PASSWORD: ${JICOFO_AUTH_PASSWORD:?set in .env}
      JVB_AUTH_PASSWORD: ${JVB_AUTH_PASSWORD:?set in .env}
      ENABLE_AUTH: "0"
      ENABLE_GUESTS: "0"
      ENABLE_XMPP_WEBSOCKET: "1"
      LOG_LEVEL: info
      # internal = local accounts only; openfire = also accept Openfire accounts
      ENABLE_REGISTRATION: "0"
      AUTH_TYPE: internal
      OPENFIRE_AUTH_ENABLED: "0"
      OPENFIRE_AUTH_HOST: 172.17.0.1
      OPENFIRE_AUTH_PORT: "5223"
      OPENFIRE_AUTH_DOMAIN: ""
      OPENFIRE_AUTH_EXCLUDE: focus,jvb,jibri,recorder
    volumes:
      - ./volumes/config:/config
    ports:
      - "5222:5222"
      - "5280:5280"
      - "5347:5347"
    networks:
      - prosody
    healthcheck:
      test: ["CMD", "/usr/local/bin/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  prosody:
    driver: bridge
    enable_ipv6: true
    ipam:
      config:
        - subnet: fd00:5a:30::/64
```
  
## Get source files  
  
```shell
dockermgr download src casjaysdevdocker/prosody
```
  
OR
  
```shell
git clone "https://github.com/casjaysdevdocker/prosody" "$HOME/Projects/github/casjaysdevdocker/prosody"
```
  
## Build container  
  
```shell
cd "$HOME/Projects/github/casjaysdevdocker/prosody"
buildx 
```
  
## Authors  
  
🤖 casjay: [Github](https://github.com/casjay) 🤖  
⛵ casjaysdevdocker: [Github](https://github.com/casjaysdevdocker) [Docker](https://hub.docker.com/u/casjaysdevdocker) ⛵  

## Authentication  

| Variable | Default | Meaning |
|---|---|---|
| `AUTH_TYPE` | `internal` | `internal` = local accounts only; `openfire` = local accounts, then Openfire |
| `OPENFIRE_AUTH_HOST` | `172.17.0.1` | Openfire direct-TLS c2s host (certificate and hostname verified) |
| `OPENFIRE_AUTH_PORT` | `5223` | Openfire direct-TLS c2s port |
| `OPENFIRE_AUTH_DOMAIN` | empty | Openfire XMPP domain (required for `AUTH_TYPE=openfire`) |
| `OPENFIRE_AUTH_EXCLUDE` | `focus,jvb,jibri,recorder` | Service accounts that never use Openfire |

Service accounts (`focus`, `jvb`, `jibri`, `jigasi`) always use local `internal_hashed`.  
Only SASL PLAIN is offered with `openfire`, since an external check cannot do SCRAM.  

## Registration  

| Variable | Default | Meaning |
|---|---|---|
| `ENABLE_REGISTRATION` | `0` | Serve `POST /user-api/register` (used by the jitsi-web `/register` page) |

Requires `ENABLE_AUTH=1` and `AUTH_TYPE=internal`; otherwise it is ignored (with a warning) or refused (403).  
Rate limited to 5 attempts per IP per hour; reserved names (`admin`, `focus`, `jvb`, ...) are rejected.  
