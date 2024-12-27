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
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

# INSTALL DEPENDENCIES
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    xvfb xauth dbus-x11 xfce4 xfce4-terminal \
    sudo curl gpg git bzip2 procps x11-xserver-utils \
    libnss3 libnspr4 libasound2 libgbm1 ca-certificates xdg-utils \
    locales fonts-liberation fonts-noto fonts-noto-cjk fonts-dejavu fonts-droid-fallback fonts-freefont-ttf \
    tigervnc-standalone-server tigervnc-common tigervnc-tools pulseaudio ffmpeg golang-go unzip nginx; \
    curl http://ftp.us.debian.org/debian/pool/main/liba/libappindicator/libappindicator3-1_0.4.92-7_amd64.deb --output /opt/libappindicator3-1_0.4.92-7_amd64.deb && \
    curl http://ftp.us.debian.org/debian/pool/main/libi/libindicator/libindicator3-7_0.5.0-4_amd64.deb --output /opt/libindicator3-7_0.5.0-4_amd64.deb && \
    apt-get install -y /opt/libappindicator3-1_0.4.92-7_amd64.deb /opt/libindicator3-7_0.5.0-4_amd64.deb; \
    rm -vf /opt/lib*.deb; \
    apt-get clean; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&  locale-gen; \
    fc-cache -fv; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# INSTALL FIREFOX
RUN install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null && \
    gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}' && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null && \
    apt-get update && apt-get install firefox

# GET NOVNC
# noVNC v1.5.0
# RUN git clone --branch v1.5.0 --single-branch https://github.com/novnc/noVNC.git /opt/noVNC
COPY noVNC.zip /opt
RUN unzip /opt/noVNC.zip -d /opt/ && rm -rf /opt/noVNC.zip /opt/__MACOSX
# websockify v0.12.0
RUN git clone --branch v0.12.0 --single-branch https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# SETUP AUDIO STREAMING LIBRARY FOR noVNC
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


# CREATE .vnc DIR
RUN mkdir -p /home/user/.vnc

# SET PERMISSION
RUN chown user:user -R /src && \
    chmod +x -R /src && \
    chown user:user -R /home/user/.vnc

# SET DEFAULT USER
USER user

WORKDIR /home/user

EXPOSE $WEB_PORT $VNC_PORT
ENTRYPOINT ["/src/entrypoint.sh"]