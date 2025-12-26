# ============================================================================
# Vein Dedicated Server Docker Container
# ============================================================================
# Based on architecture patterns from ark-sa-server project
# Leverages Vein's native Linux server (no Wine/Proton needed)
# ============================================================================

# -----------------------------------------------------------------------------
# Base Image: Ubuntu 22.04 with SteamCMD pre-installed
# -----------------------------------------------------------------------------
FROM steamcmd/steamcmd:ubuntu-22

# -----------------------------------------------------------------------------
# Metadata Labels
# -----------------------------------------------------------------------------
LABEL maintainer="Vein Server Project"
LABEL description="Vein dedicated game server with automated management"
LABEL version="1.0.0"

# -----------------------------------------------------------------------------
# Install System Dependencies
# -----------------------------------------------------------------------------
# Update package lists and install required packages
# supervisor: Process management (finite state machine orchestration)
# cron: Scheduled operations (restarts, updates, backups)
# curl: Health checks and API interactions
# procps: Process monitoring (ps, top commands)
# ca-certificates: SSL/TLS certificate validation
# tzdata: Timezone support
# zip/unzip: Backup compression (ZIP format option)
# tar: Backup compression (tar.gz format)
# bash: Script execution environment
# vim: Debug/troubleshooting (minimal editor)
# net-tools: Network diagnostics (netstat, ifconfig)
# ============================================================================
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
        net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Create Non-Root User
# -----------------------------------------------------------------------------
# Create steam user (UID:GID 1000:1000) if it doesn't exist
# This user will run all processes for security
# ============================================================================
RUN if ! id -u steam > /dev/null 2>&1; then \
        groupadd -g 1000 steam && \
        useradd -u 1000 -g 1000 -m -s /bin/bash steam; \
    fi

# -----------------------------------------------------------------------------
# Create Directory Structure
# -----------------------------------------------------------------------------
# /vein-server/server   - VOLUME: Game server files (SteamCMD downloads here)
# /vein-server/logs     - VOLUME: All log files (supervisord, server, scripts)
# /vein-server/backups  - VOLUME: Backup archives
# /vein-server/scripts  - Scripts (copied in PR 1.8)
# /vein-server/templates - Config templates (copied in PR 1.8)
# /vein-server/supervisord - Supervisord config (copied in PR 1.8)
# /vein-server/cron     - Cron config (copied in PR 1.8)
# ============================================================================
RUN mkdir -p \
    /vein-server/server \
    /vein-server/logs \
    /vein-server/backups \
    /vein-server/scripts \
    /vein-server/templates \
    /vein-server/supervisord \
    /vein-server/cron && \
    chown -R steam:steam /vein-server

# -----------------------------------------------------------------------------
# Set Working Directory
# -----------------------------------------------------------------------------
WORKDIR /vein-server

# -----------------------------------------------------------------------------
# Switch to Non-Root User
# -----------------------------------------------------------------------------
# Security: Run container as steam user (UID:GID 1000:1000)
# Set HOME to steam user's home directory to avoid /root/.bashrc errors
USER steam
ENV HOME=/home/steam

# -----------------------------------------------------------------------------
# Expose Ports
# -----------------------------------------------------------------------------
# 7777/UDP  - Game port (players connect here)
# 27015/UDP - Steam query port (server browser)
# 8080/TCP  - HTTP API (future enhancement - not in Phase 1)
# ============================================================================
EXPOSE 7777/udp 27015/udp 8080/tcp

# -----------------------------------------------------------------------------
# Volume Definitions
# -----------------------------------------------------------------------------
# These volumes persist data across container recreations
# ============================================================================
VOLUME ["/vein-server/server", "/vein-server/logs", "/vein-server/backups"]

# -----------------------------------------------------------------------------
# Health Check (Placeholder)
# -----------------------------------------------------------------------------
# Will be implemented in PR 6.3
# For now, basic check that container is running
# ============================================================================
HEALTHCHECK --interval=60s --timeout=10s --start-period=300s --retries=3 \
    CMD pgrep -x "supervisord" > /dev/null || exit 1

# -----------------------------------------------------------------------------
# Container Metadata
# -----------------------------------------------------------------------------
# Override base image ENTRYPOINT (steamcmd) - will be set to system-bootstrap.sh in PR 1.8
# For now, no entrypoint allows container to run bash for testing
# ============================================================================
ENTRYPOINT []
CMD ["/bin/bash"]
