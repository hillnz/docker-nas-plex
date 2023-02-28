# renovate: datasource=docker depName=jonoh/plex versioning=regex:^1\.(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+).+
ARG PLEX_VERSION=1.31.1.6733-bc0674160

FROM --platform=$BUILDPLATFORM curlimages/curl AS downloader

ARG TARGETPLATFORM

WORKDIR /home/curl_user

# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.61.1
RUN RCLONE_PLATFORM=$(echo $TARGETPLATFORM | sed 's|/|-|g' ) && \
    curl -L -o rclone.deb https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_PLATFORM}.deb

# renovate: datasource=github-releases depName=ytdl-org/youtube-dl versioning=regex:^(?<major>\d+)\.0?(?<minor>\d+)\.0?(?<patch>\d+)$
ARG YOUTUBEDL_VERSION=2021.12.17
# Platform independent - zipped python file
RUN curl -L -o youtube-dl https://github.com/ytdl-org/youtube-dl/releases/download/${YOUTUBEDL_VERSION}/youtube-dl && \
    chmod a+rx youtube-dl

FROM jonoh/plex:${PLEX_VERSION}

ARG TARGETPLATFORM

COPY --from=downloader /home/curl_user/*.deb /tmp/
COPY --from=downloader /home/curl_user/youtube-dl /usr/local/bin/youtube-dl    

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \ 
    dirmngr \
    curl \
    ffmpeg \
    file \ 
    fuse \
    git \
    python \
    ruby \
    sqlite \
    unzip \
    wget \
    && \
    apt install -y /tmp/*.deb && rm /tmp/*.deb

RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs

RUN npm install -g antennas

RUN groupadd fuse && usermod -a -G fuse plex
ENV RCLONE_MOUNT_DIR= RCLONE_MOUNT_TARGET=
ENV RCLONE_CONFIG=/config/rclone.conf
ENV RCLONE_CACHE_PATH=/caches
ENV INCOMING_DIR=/data/incoming
ENV RCLONE_UPLOAD_BWLIMIT=0
ENV RCLONE_CACHE_MAX_SIZE=25G
ENV RCLONE_WRITE_BACK=5s

RUN rm /etc/cont-init.d/50-plex-update

COPY root/ /

HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=2 CMD /healthcheck.sh || /dvr_healthcheck.py || exit 1
