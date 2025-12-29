# Docker Compose Deployment Examples

This directory contains example Docker Compose configurations for deploying Vein dedicated servers.

## Examples

### Basic Setup

`basic-docker-compose.yml` - Minimal configuration with sensible defaults.

**Features:**
- Server name and password configuration
- Three persistent volumes (server, backups, logs)
- Game and query port exposure

**Usage:**
```bash
docker-compose -f basic-docker-compose.yml up -d
```

### Advanced Setup

`advanced-docker-compose.yml` - Full-featured configuration with all options.

**Features:**
- Complete server identity configuration
- Backup settings with retention policy
- Scheduled restarts, updates, and backups (disabled by default)
- Advanced CONFIG_ variable examples

**Usage:**
```bash
docker-compose -f advanced-docker-compose.yml up -d
```

## Common Operations

### View Logs
```bash
docker logs -f vein
```

### Stop Server
```bash
docker-compose -f <compose-file>.yml down
```

### Manual Backup
```bash
docker exec vein supervisorctl start vein-backup
```

### Check Server Status
```bash
docker exec vein supervisorctl status
```

## Data Management

### Volumes

| Volume | Purpose | Typical Size |
|--------|---------|--------------|
| `vein-server` | Game files | 20-30GB |
| `vein-backups` | Backup archives | Varies |
| `vein-logs` | Log files | <1GB |

### Backup Location

Backups are stored in the `vein-backups` volume as timestamped archives:
- `vein-server-YYYYMMDDHHMMSS.tar.gz` (default)
- `vein-server-YYYYMMDDHHMMSS.zip` (if `ZIP_BACKUPS=True`)

## Environment Variables

See the main [README](../../README.md) for a complete list of environment variables.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 7777 | UDP | Game port (players connect here) |
| 27015 | UDP | Steam query port (server browser) |
