# renovate: datasource=docker depName=jonoh/plex-tellytv-test versioning=regex:^1\.(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+).+
ARG PLEX_VERSION=1.22.2.4282-a97b03fad

FROM --platform=$BUILDPLATFORM curlimages/curl AS downloader

ARG TARGETPLATFORM

WORKDIR /home/curl_user

# renovate: datasource=repology depName=homebrew_casks/FileBot
ARG FILEBOT_VERSION=4.9.3
RUN curl -L -o filebot.deb https://get.filebot.net/filebot/FileBot_${FILEBOT_VERSION}/FileBot_${FILEBOT_VERSION}_universal.deb

# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.55.0
RUN RCLONE_PLATFORM=$(echo $TARGETPLATFORM | sed 's|/|-|g' ) && \
    curl -L -o rclone.deb https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_PLATFORM}.deb

# renovate: datasource=github-releases depName=ytdl-org/youtube-dl versioning=regex:^(?<major>\d+)\.0?(?<minor>\d+)\.0?(?<patch>\d+)$
ARG YOUTUBEDL_VERSION=2021.04.01
# Platform independent - zipped python file
RUN curl -L -o youtube-dl https://github.com/ytdl-org/youtube-dl/releases/download/${YOUTUBEDL_VERSION}/youtube-dl && \
    chmod a+rx youtube-dl

FROM jonoh/plex-tellytv-test:${PLEX_VERSION}

ARG TARGETPLATFORM

COPY --from=downloader /home/curl_user/*.deb /tmp/
COPY --from=downloader /home/curl_user/youtube-dl /usr/local/bin/youtube-dl    

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \ 
    dirmngr \
    curl \
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

RUN groupadd fuse && usermod -a -G fuse plex
ENV RCLONE_MOUNT_DIR= RCLONE_MOUNT_TARGET=
ENV RCLONE_CONFIG=/config/rclone.conf
ENV RCLONE_CACHE_PATH=/caches
ENV INCOMING_DIR=/data/incoming
ENV FILEBOT_LICENSE=/config/filebot.psm
ENV RCLONE_UPLOAD_BWLIMIT=0

COPY root/ /
