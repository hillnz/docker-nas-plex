FROM --platform=$BUILDPLATFORM curlimages/curl AS downloader

ARG TARGETPLATFORM

WORKDIR /home/curl_user

# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.70.3
RUN RCLONE_PLATFORM=$(echo $TARGETPLATFORM | sed 's|/|-|g' ) && \
    curl -L -o rclone.deb https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_PLATFORM}.deb

# renovate: datasource=github-releases depName=ytdl-org/youtube-dl versioning=regex:^(?<major>\d+)\.0?(?<minor>\d+)\.0?(?<patch>\d+)$
ARG YOUTUBEDL_VERSION=2021.12.17
# Platform independent - zipped python file
RUN curl -L -o youtube-dl https://github.com/ytdl-org/youtube-dl/releases/download/${YOUTUBEDL_VERSION}/youtube-dl && \
    chmod a+rx youtube-dl

FROM linuxserver/plex:1.41.9

ARG TARGETPLATFORM

COPY --from=downloader /home/curl_user/*.deb /tmp/
COPY --from=downloader /home/curl_user/youtube-dl /usr/local/bin/youtube-dl

COPY --from=caddy:2.10.0 /usr/bin/caddy /usr/bin/caddy

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \ 
    dirmngr \
    curl \
    ffmpeg \
    file \ 
    fuse3 \
    git \
    libnss3-tools \
    libssl-dev \
    python3 \
    ruby \
    sqlite3 \
    unzip \
    wget \
    && \
    apt install -y /tmp/*.deb && rm /tmp/*.deb

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

COPY root/ /
