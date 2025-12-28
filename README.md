# Vein Game Server - Docker Container

A Docker container for running Vein dedicated game servers with automated management, based on the architecture patterns from [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server).

## Features

- **Automated Installation** - SteamCMD downloads and installs server files automatically
- **Environment Variable Configuration** - Configure server settings via ENV vars
- **Scheduled Restarts** - Automatic server restarts on a cron schedule
- **Scheduled Updates** - Automatic server updates on a cron schedule
- **Automated Backups** - Multiple backup triggers with retention policy
- **Native Linux** - No Wine/Proton overhead (Vein has native Linux server)
- **Graceful Shutdown** - Automatic backup on container stop

## Quick Start

### Linux

```bash
docker run -d \
  --name vein \
  -p 7777:7777/udp \
  -p 27015:27015/udp \
  -v vein-server:/vein-server/server \
  -v vein-backups:/vein-server/backups \
  -v vein-logs:/vein-server/logs \
  -e VEIN_SERVER_NAME="My Vein Server" \
  -e VEIN_SERVER_PASSWORD="secretpassword" \
  vein-server:latest
```

### Docker Compose

```bash
# Clone the repository
git clone https://github.com/your-repo/vein-server.git
cd vein-server

# Start the server
docker-compose up -d

# View logs
docker logs -f vein-server
```

See [deployment-examples/](deployment-examples/) for more configuration examples.

## System Requirements

- **RAM:** 8GB minimum, 12GB recommended
- **CPU:** 4 cores modern CPU
- **Storage:** 20GB minimum (SSD recommended)
- **OS:** Linux with Docker installed

## Configuration

### Environment Variables

#### Server Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_SERVER_NAME` | "Vein Server" | Server name shown in browser |
| `VEIN_SERVER_DESCRIPTION` | "A Vein dedicated server" | Server description |
| `VEIN_SERVER_PASSWORD` | "" | Server password (empty = no password) |
| `VEIN_SERVER_PUBLIC` | "True" | Show in server browser |
| `VEIN_SERVER_MAX_PLAYERS` | "16" | Maximum players |
| `VEIN_SERVER_PORT` | "7777" | Game port (UDP) |
| `VEIN_SERVER_QUERY_PORT` | "27015" | Query port (UDP) |

#### Update Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_ON_BOOT` | "True" | Check for updates on container start |
| `MANUAL_CONFIG` | "False" | Skip config generation (use your own) |

#### Backup Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ON_STOP` | "True" | Backup on container shutdown |
| `BACKUP_BEFORE_UPDATE` | "True" | Backup before SteamCMD updates |
| `BACKUP_ON_SCHEDULED_RESTART` | "False" | Backup before scheduled restarts |
| `SCHEDULED_BACKUP` | "False" | Enable standalone backup cron |
| `BACKUP_CRON` | "0 6 * * *" | Backup schedule (6 AM daily) |
| `ZIP_BACKUPS` | "False" | Use ZIP format (False = tar.gz) |
| `RETAIN_BACKUPS` | "" | Number of backups to keep (empty = unlimited) |

#### Scheduling Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `SCHEDULED_RESTART` | "False" | Enable scheduled restarts |
| `RESTART_CRON` | "0 4 * * *" | Restart schedule (4 AM daily) |
| `SCHEDULED_UPDATE` | "False" | Enable scheduled updates |
| `UPDATE_CRON` | "0 3 * * *" | Update schedule (3 AM daily) |

#### Advanced Configuration

For settings not covered by simple ENV vars, use `CONFIG_` variables:

```yaml
# Format: CONFIG_<filename>_<section>_<variable>=<value>
# Use SLASH for / and DOT for . in section names

CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_AdminSteamIDs: "76561198012345678"
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 7777 | UDP | Game port (players connect here) |
| 27015 | UDP | Steam query port (server browser) |

Ensure these ports are forwarded on your router/firewall for external access.

## Volumes

| Volume | Container Path | Purpose |
|--------|----------------|---------|
| Server Data | `/vein-server/server` | Game files (20-30GB) |
| Backups | `/vein-server/backups` | Backup archives |
| Logs | `/vein-server/logs` | Log files |

## Backups

### Backup Triggers

Backups can be triggered in four ways:

1. **On Stop** (`BACKUP_ON_STOP=True`) - When container receives SIGTERM
2. **Before Update** (`BACKUP_BEFORE_UPDATE=True`) - Before SteamCMD runs
3. **Scheduled Restart** (`BACKUP_ON_SCHEDULED_RESTART=True`) - Before scheduled restart
4. **Standalone Cron** (`SCHEDULED_BACKUP=True`) - Independent scheduled backups

### Manual Backup

```bash
docker exec vein-server supervisorctl start vein-backup
```

### Backup Format

- Default: `vein-server-YYYYMMDDHHMMSS.tar.gz`
- With `ZIP_BACKUPS=True`: `vein-server-YYYYMMDDHHMMSS.zip`

### Retention

Set `RETAIN_BACKUPS` to limit the number of backups kept:
- Empty (default): Keep all backups
- Number (e.g., `10`): Keep only the 10 most recent

## Scheduled Operations

### Scheduled Restarts

```yaml
SCHEDULED_RESTART: "True"
RESTART_CRON: "0 4 * * *"  # 4 AM daily
BACKUP_ON_SCHEDULED_RESTART: "True"  # Optional: backup first
```

### Scheduled Updates

```yaml
SCHEDULED_UPDATE: "True"
UPDATE_CRON: "0 3 * * 0"  # 3 AM every Sunday
BACKUP_BEFORE_UPDATE: "True"  # Recommended
```

### Scheduled Backups

```yaml
SCHEDULED_BACKUP: "True"
BACKUP_CRON: "0 */6 * * *"  # Every 6 hours
```

## Common Operations

### View Logs
```bash
docker logs -f vein-server
```

### Check Process Status
```bash
docker exec vein-server supervisorctl status
```

### Manual Update
```bash
docker exec vein-server supervisorctl start vein-updater
```

### Restart Server
```bash
docker exec vein-server supervisorctl restart vein-server
```

### Stop Container Gracefully
```bash
docker stop vein-server
# or
docker-compose down
```

## Troubleshooting

### Server Won't Start

1. Check logs: `docker logs vein-server`
2. Verify disk space: `docker exec vein-server df -h`
3. Check bootstrap log: `docker exec vein-server cat /vein-server/logs/bootstrap.log`

### Configuration Not Applying

1. Verify ENV vars: `docker exec vein-server env | grep VEIN_`
2. Check generated config: `docker exec vein-server cat /vein-server/server/Vein/Saved/Config/LinuxServer/Game.ini`
3. Ensure `MANUAL_CONFIG` is not "True"

### Backups Not Working

1. Check backup log: `docker exec vein-server cat /vein-server/logs/backup.log`
2. Verify disk space: `docker exec vein-server df -h /vein-server/backups`
3. Check process status: `docker exec vein-server supervisorctl status vein-backup`

### Cron Jobs Not Running

1. Verify cron is running: `docker exec vein-server ps aux | grep cron`
2. Check crontab: `docker exec vein-server crontab -l`
3. View cron log: `docker exec vein-server cat /vein-server/logs/cron.log`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server) - Reference architecture and patterns
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) - Server file distribution
