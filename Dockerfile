FROM --platform=$BUILDPLATFORM curlimages/curl AS downloader

ARG TARGETPLATFORM

WORKDIR /home/curl_user

# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.74.4
RUN RCLONE_PLATFORM=$(echo $TARGETPLATFORM | sed 's|/|-|g' ) && \
    curl -L -o rclone.deb https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_PLATFORM}.deb

# renovate: datasource=github-releases depName=ytdl-org/youtube-dl versioning=regex:^(?<major>\d+)\.0?(?<minor>\d+)\.0?(?<patch>\d+)$
ARG YOUTUBEDL_VERSION=2021.12.17
# Platform independent - zipped python file
RUN curl -L -o youtube-dl https://github.com/ytdl-org/youtube-dl/releases/download/${YOUTUBEDL_VERSION}/youtube-dl && \
    chmod a+rx youtube-dl

FROM ghcr.io/tailscale/tailscale:v1.98.8 AS tailscale

FROM ubuntu:24.04 AS filestash_build

COPY --from=golang:1.26 /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:$PATH

# renovate: datasource=git-refs depName=https://github.com/mickael-kerjean/filestash
ARG FILESTASH_VERSION=f726b385704cefa79f0a0149d7afeeddae8e07c5

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    g++ \
    gcc \
    git \
    make \
    pkg-config \
    libjpeg-dev libtiff-dev libpng-dev libwebp-dev libraw-dev libheif-dev libgif-dev libvips-dev liblcms2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# Without video transcoder, which wants newer ffmpeg
RUN git clone https://github.com/mickael-kerjean/filestash . && \
    git checkout "${FILESTASH_VERSION}" && \
    sed -i '/plg_video_transcoder/d' server/plugin/index.go && \
    make init && \
    make build && \
    mkdir -p dist/data/state/config

COPY filestash/config.json /src/dist/data/state/config/config.json

FROM linuxserver/plex:1.43.2

ARG TARGETPLATFORM

COPY --from=downloader /home/curl_user/*.deb /tmp/
COPY --from=downloader /home/curl_user/youtube-dl /usr/local/bin/youtube-dl

COPY --from=tailscale /usr/local/bin/tailscale /usr/bin/tailscale
COPY --from=tailscale /usr/local/bin/tailscaled /usr/bin/tailscaled

COPY --from=caddy:2.11.4 /usr/bin/caddy /usr/bin/caddy

COPY --from=filestash_build /src/dist/ /app/

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \
    dirmngr \
    curl \
    ffmpeg \
    file \
    fuse3 \
    git \
    libbrotli1 \
    libnss3-tools \
    libssl-dev \
    python3 \
    ruby \
    sqlite3 \
    unzip \
    wget \
    && \
    apt install -y /tmp/*.deb && rm /tmp/*.deb && \
    chmod 755 /app/filestash

RUN groupadd fuse && usermod -a -G fuse abc
ENV RCLONE_MOUNT_DIR= RCLONE_MOUNT_TARGET=
ENV RCLONE_CONFIG=/config/rclone.conf
ENV RCLONE_CACHE_PATH=/caches
ENV INCOMING_DIR=/data/incoming
ENV RCLONE_UPLOAD_BWLIMIT=0
ENV RCLONE_CACHE_MAX_SIZE=25G
ENV RCLONE_WRITE_BACK=5s

ENV RCLONE_CONFIG_HTTP=/config/rclone-http.conf
ENV RCLONE_HTTP_PORT=32500

# Tailscale configuration for userspace networking mode
# TS_AUTHKEY: Tailscale auth key for automatic authentication
# Generate at: https://login.tailscale.com/admin/settings/keys
# For persistent auth, use a reusable key. Leave empty for interactive login via URL.
ENV TS_AUTHKEY=

# TS_HOSTNAME: The hostname to register with Tailscale (shows in admin console)
ENV TS_HOSTNAME=

# TS_STATE_DIR: Directory to persist Tailscale state across container restarts
# This should be a mounted volume to maintain identity between restarts
ENV TS_STATE_DIR=/config/tailscale

# TS_SOCKET: Path to the tailscaled Unix socket
ENV TS_SOCKET=/var/run/tailscale/tailscaled.sock

# TS_ACCEPT_DNS: Whether to use Tailscale's MagicDNS configuration
# Set to "true" to use tailnet DNS, "false" to keep container's DNS settings
ENV TS_ACCEPT_DNS=false

# TS_EXTRA_ARGS: Additional arguments to pass to 'tailscale up'
# Examples: "--advertise-exit-node" "--accept-routes" "--shields-up"
ENV TS_EXTRA_ARGS=

# TS_TAILSCALED_EXTRA_ARGS: Additional arguments to pass to 'tailscaled'
# Example: "--verbose=2" for debug logging
ENV TS_TAILSCALED_EXTRA_ARGS=

# TS_SOCKS5_SERVER: Address to listen for SOCKS5 proxy connections (optional)
# Example: "0.0.0.0:1055" to expose SOCKS5 proxy for tailnet access
ENV TS_SOCKS5_SERVER=

# TS_OUTBOUND_HTTP_PROXY_LISTEN: Address to listen for HTTP proxy connections (optional)
# Example: "0.0.0.0:8080" to expose HTTP proxy for tailnet access
ENV TS_OUTBOUND_HTTP_PROXY_LISTEN=

# Taildrive configuration
# TS_DRIVE_SHARES: Comma-separated list of shares in "name:path" format
# Example: "media:/data/media,config:/config" to share multiple directories
# Note: Requires "drive:share" node attribute in your Tailscale ACLs
# Access requires "drive:access" node attribute on accessing nodes
# Shares are accessible via WebDAV at http://100.100.100.100:8080/<tailnet>/<hostname>/<sharename>
ENV TS_DRIVE_SHARES=

# filestash
ENV FILESTASH_STATE_DIR=/config/filestash
ENV CONFIG_ENCRYPT=false
ENV LOCAL_BACKEND_SECRET=filestash
EXPOSE 8334

COPY root/ /
