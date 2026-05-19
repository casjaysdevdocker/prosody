# =============================================================================
# Jitsi Source Stage — extract plugins and pure-Lua libs from the official
# jitsi/prosody image at build time so we never fetch at runtime
# =============================================================================
FROM jitsi/prosody:stable AS jitsi-source

# =============================================================================
# Runtime Stage
# =============================================================================
FROM alpine:latest

ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF
ARG LICENSE=MIT

# Install runtime dependencies
# prosody from Alpine 13.x matches jitsi/prosody:stable (also 13.x)
# su-exec drops from root to prosody user before exec
RUN apk add --no-cache \
    bash \
    curl \
    openssl \
    prosody \
    su-exec \
    tini

# Apply prosody 13.x compatibility patch:
# idna_to_ascii was removed in libicu 72+ but the Lua util still references it;
# the jitsi base image applies this same patch (sed -i '/idna_to_ascii/d')
RUN sed -i '/idna_to_ascii/d' /usr/lib/prosody/util/jid.lua 2>/dev/null || true

# Create runtime directories
RUN mkdir -p \
    /config/certs \
    /config/conf.d \
    /config/data \
    /prosody-plugins \
    /prosody-plugins-contrib \
    /prosody-plugins-custom

# Copy Jitsi-specific prosody plugins (pure Lua — architecture-independent)
COPY --from=jitsi-source /prosody-plugins /prosody-plugins
COPY --from=jitsi-source /prosody-plugins-contrib /prosody-plugins-contrib

# Copy pure-Lua libraries that the Jitsi plugins depend on (basexx, net-url, etc.)
# We do NOT copy /usr/local/lib/lua (compiled .so for glibc/Debian — incompatible with musl/Alpine)
# lua5.4-cjson is provided by Alpine's prosody dependency and takes precedence
COPY --from=jitsi-source /usr/local/share/lua/5.4 /usr/local/share/lua/5.4

# Copy rootfs overlay (mirrors Linux FHS)
COPY docker/rootfs/ /

# Copy Dockerfile into image for reference
COPY docker/Dockerfile /root/Dockerfile

# Set ownership and permissions
RUN chown -R prosody:prosody /config /prosody-plugins-custom /prosody-plugins-contrib && \
    chmod 755 /usr/local/bin/*

# BOSH + WebSocket (5280), c2s client connections (5222), component connections (5347)
EXPOSE 5222 5280 5347

STOPSIGNAL SIGRTMIN+3

HEALTHCHECK --start-period=2m --interval=1m --timeout=10s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

ENTRYPOINT [ "tini", "-p", "SIGTERM", "--", "/usr/local/bin/entrypoint.sh" ]
