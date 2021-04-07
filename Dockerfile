# renovate: datasource=docker depName=jonoh/plex-tellytv-test versioning=regex:^1\.(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+).+
ARG PLEX_VERSION=1.22.1.4275-48e10484b
FROM jonoh/plex-tellytv-test:${PLEX_VERSION}

ARG TARGETPLATFORM

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
    wget

# Filebot
# renovate: datasource=repology depName=homebrew_casks/FileBot
ARG FILEBOT_VERSION=4.9.3
ENV INCOMING_DIR=/data/incoming
ENV FILEBOT_LICENSE=/config/filebot.psm
ENV RCLONE_UPLOAD_BWLIMIT=0
RUN curl -L -o /tmp/filebot.deb https://get.filebot.net/filebot/FileBot_${FILEBOT_VERSION}/FileBot_${FILEBOT_VERSION}_universal.deb && \
    apt install -y /tmp/filebot.deb && \
    rm /tmp/filebot.deb

# Rclone
# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.55.0
RUN echo $TARGETPLATFORM && RCLONE_PLATFORM=$(echo $TARGETPLATFORM | sed 's|/|-|g' ) && \
    curl -L -o /tmp/rclone.deb https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_PLATFORM}.deb && \
    apt install -y /tmp/rclone.deb && \
    rm /tmp/rclone.deb

ENV RCLONE_MOUNT_DIR= RCLONE_MOUNT_TARGET=
ENV RCLONE_CONFIG=/config/rclone.conf
ENV RCLONE_CACHE_PATH=/caches
RUN groupadd fuse && usermod -a -G fuse plex

# renovate: datasource=github-releases depName=ytdl-org/youtube-dl versioning=regex:^(?<major>\d+)\.0?(?<minor>\d+)\.0?(?<patch>\d+)$
RUN YOUTUBEDL_VERSION=2021.04.01
# Platform independent - zipped python file
RUN curl -L https://github.com/ytdl-org/youtube-dl/releases/download/${YOUTUBEDL_VERSION}/youtube-dl -o /usr/local/bin/youtube-dl && \
    chmod a+rx /usr/local/bin/youtube-dl

COPY root/ /
