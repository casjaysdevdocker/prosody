## Project description

A production-ready Docker image for [Prosody XMPP](https://prosody.im/) configured specifically for Jitsi Meet deployments. Replaces the upstream `jitsi/docker-jitsi-meet` prosody image with a standards-compliant CasjaysDev image built on Alpine Linux with full BOSH and WebSocket support (mod_websocket).

## Project variables

```
project_name:    prosody
project_org:     casjaysdevdocker
internal_name:   prosody
internal_org:    casjaysdevdocker
image_registry:  ghcr.io
upstream_image:  prosody (Alpine package)
jitsi_repo:      https://github.com/jitsi/docker-jitsi-meet
```

## Business logic

- Must be a drop-in replacement for `jitsi/docker-jitsi-meet` prosody container
- Must support all standard Jitsi Docker env vars: `XMPP_DOMAIN`, `XMPP_AUTH_DOMAIN`, `XMPP_MUC_DOMAIN`, `XMPP_INTERNAL_MUC_DOMAIN`, `XMPP_GUEST_DOMAIN`, `JICOFO_AUTH_PASSWORD`, `JVB_AUTH_PASSWORD`, `ENABLE_AUTH`, `ENABLE_GUESTS`, `ENABLE_XMPP_WEBSOCKET`, `PUBLIC_URL`, `LOG_LEVEL`
- Must have BOSH working on `/http-bind` at port 5280
- Must have WebSocket working on `/xmpp-websocket` at port 5280 (this is the primary fix over upstream)
- Must register jicofo and jvb users automatically at startup
- Must generate self-signed TLS certificates for Jitsi domains at startup if not present
- Must expose ports 5222 (c2s), 5280 (HTTP/BOSH/WS), 5347 (component)
- Must include all Jitsi prosody plugins from `jitsi/docker-jitsi-meet` prosody image
- Must run prosody as the `prosody` system user (non-root), not as root
- Must use `tini` as PID 1
- Must work with zero config — sane defaults for all env vars
- Must NOT require a separate nginx reverse proxy in the container
- Must NOT include s6 or any other process supervisor — single process per container
- `consider_websocket_secure = true` and `consider_bosh_secure = true` must always be set so trusted-proxy HTTPS termination works
