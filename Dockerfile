FROM debian:12

# ENVIRONMENT VARIABLES
ENV DISPLAY=:1 \
    USER_PASSWORD='password' \
    VNC_PASSWORD='password' \
    WEB_PORT=80 \
    VNC_PORT=5901 \
    NO_VNC_PORT=10000 \
    AUDIO_STREAM_PORT=10001 \
    VNC_COL_DEPTH=32 \
    VNC_RESOLUTION=1024x768 \
    DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# INSTALL DEPENDENCIES
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    xvfb xauth dbus-x11 xfce4 xfce4-terminal \
    sudo curl gpg git bzip2 procps x11-xserver-utils \
    libnss3 libnspr4 libasound2 libgbm1 ca-certificates xdg-utils \
    fonts-liberation fonts-noto fonts-noto-cjk fonts-dejavu fonts-droid-fallback fonts-freefont-ttf \
    tigervnc-standalone-server tigervnc-common tigervnc-tools pulseaudio ffmpeg golang-go unzip nginx; \
    curl http://ftp.us.debian.org/debian/pool/main/liba/libappindicator/libappindicator3-1_0.4.92-7_amd64.deb --output /opt/libappindicator3-1_0.4.92-7_amd64.deb && \
    curl http://ftp.us.debian.org/debian/pool/main/libi/libindicator/libindicator3-7_0.5.0-4_amd64.deb --output /opt/libindicator3-7_0.5.0-4_amd64.deb && \
    apt-get install -y /opt/libappindicator3-1_0.4.92-7_amd64.deb /opt/libindicator3-7_0.5.0-4_amd64.deb; \
    rm -vf /opt/lib*.deb; \
    apt-get clean; \
    fc-cache -fv; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ADD GOOGLE CHROME REPOSITORY
RUN apt-get update -y && apt-get upgrade -y && \
    curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# INSTALL GOOGLE CHROME
RUN apt-get update -y && \
    apt-get install -y google-chrome-stable

# GET NOVNC
COPY noVNC.zip /opt
RUN unzip /opt/noVNC.zip -d /opt/ && rm -rf /opt/noVNC.zip /opt/__MACOSX
# RUN git clone --branch v1.5.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC
RUN git clone --branch v0.12.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# COPY JS LIBRARIES
COPY jsmpeg.min.js /opt/noVNC

# CREATE USER
RUN useradd -ms /bin/bash user && \
    usermod -aG sudo user && \
    echo "user:$USER_PASSWORD" | chpasswd

# GIVE USER PERMISSION TO RUN NGINX WITHOUT PASSWORD
RUN echo "user ALL=(ALL) NOPASSWD: /usr/sbin/nginx" >> /etc/sudoers
    
# COPY SCRIPT
RUN mkdir /src
COPY entrypoint.sh /src
RUN chmod +x /src/entrypoint.sh

# COMPILE audio_server
RUN mkdir /src/audio_streaming
WORKDIR /src/audio_streaming
COPY audio_server.go .
RUN go mod init audio_server
RUN go get github.com/gorilla/websocket
RUN go build -o audio_server audio_server.go
RUN rm -rf audio_server.go go.mod go.sum

# NGINX PROXY
COPY nginx.conf /etc/nginx
RUN nginx -t

RUN chown user:user -R /src && chmod +x -R /src

# SET DEFAULT USER
USER user

WORKDIR /home/user

EXPOSE $WEB_PORT $VNC_PORT
ENTRYPOINT ["/src/entrypoint.sh"]