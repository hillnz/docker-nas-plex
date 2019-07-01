FROM jonoh/plex-tellytv:latest

RUN sed 's@http://archive.ubuntu.com/ubuntu@mirror://mirrors.ubuntu.com/mirrors.txt@' -i /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    build-essential \ 
    dirmngr \
    curl \
    file \ 
    fuse \
    git \
    gnupg-curl \
    python \
    ruby \
    sqlite \
    unzip \
    wget

# Rclone
RUN mkdir -p /opt/rclone
WORKDIR /opt/rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.zip -O rclone.zip && \
    unzip -j rclone.zip

ENV RCLONE_MOUNT_DIR= RCLONE_MOUNT_TARGET=
ENV RCLONE_CONFIG=/config/rclone.conf
ENV RCLONE_CACHE_PATH=/caches
RUN groupadd fuse && usermod -a -G fuse plex

RUN curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
    chmod a+rx /usr/local/bin/youtube-dl

COPY root/ /
