FROM steamcmd/steamcmd:ubuntu-22

LABEL maintainer="Vein Server Project"
LABEL description="Vein dedicated game server with automated management"
LABEL version="1.0.0"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        supervisor \
        cron \
        curl \
        procps \
        ca-certificates \
        tzdata \
        zip \
        unzip \
        tar \
        bash \
        vim \
        net-tools \
        python3 \
        libatomic1 \
        libasound2 \
        libpulse0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN if ! id -u steam > /dev/null 2>&1; then \
        groupadd -g 1000 steam && \
        useradd -u 1000 -g 1000 -m -s /bin/bash steam; \
    fi && \
    usermod -a -G crontab steam

RUN mkdir -p \
    /vein-server/server \
    /vein-server/logs \
    /vein-server/backups \
    /vein-server/bin \
    /vein-server/supervisord

COPY bin/ /vein-server/bin/
COPY supervisord/ /vein-server/supervisord/
COPY config_from_env_vars/ /usr/local/bin/config_from_env_vars/

RUN chown -R steam:steam /vein-server && \
    chmod +x /vein-server/bin/*.sh && \
    chown -R steam:steam /usr/local/bin/config_from_env_vars && \
    chmod +x /usr/local/bin/config_from_env_vars/main.py

WORKDIR /vein-server

ENV SERVER_DIR="/vein-server/server" \
    BACKUPS_DIR="/vein-server/backups" \
    HOME=/home/steam \
    VEIN_SERVER_NAME="Vein Server" \
    VEIN_SERVER_DESCRIPTION="A Vein dedicated server" \
    VEIN_SERVER_PASSWORD="" \
    VEIN_SERVER_PUBLIC="True" \
    VEIN_SERVER_MAX_PLAYERS="16" \
    VEIN_SERVER_PORT="7777" \
    VEIN_SERVER_QUERY_PORT="27015" \
    VEIN_BIND_ADDR="0.0.0.0" \
    VEIN_HEARTBEAT_INTERVAL="5.0" \
    VEIN_VAC_ENABLED="0" \
    UPDATE_ON_BOOT="True" \
    VALIDATE_SERVER_FILES="True" \
    BACKUP_ON_STOP="True" \
    BACKUP_ON_SCHEDULED_RESTART="False" \
    BACKUP_BEFORE_UPDATE="True" \
    ZIP_BACKUPS="False" \
    RETAIN_BACKUPS="" \
    SCHEDULED_BACKUP="False" \
    BACKUP_CRON="0 6 * * *" \
    SCHEDULED_RESTART="False" \
    RESTART_CRON="0 4 * * *" \
    SCHEDULED_UPDATE="False" \
    UPDATE_CRON="0 3 * * *" \
    MANUAL_CONFIG="False" \
    EXPERIMENTAL_BUILD="False"

EXPOSE 7777/udp 27015/udp 8080/tcp

VOLUME ["/vein-server/server", "/vein-server/logs", "/vein-server/backups"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=300s --retries=3 \
    CMD pgrep -x "supervisord" > /dev/null || exit 1

ENTRYPOINT ["/vein-server/bin/system-bootstrap.sh"]
