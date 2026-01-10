# CLAUDE.md - Vein Game Server Docker Container

## Project Overview

Docker containerization solution for running Vein dedicated game servers, based on the architecture and patterns from [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server).

**Key Features:**
- Supervisord-based finite state machine for process orchestration
- Native Linux server (no Wine/Proton required)
- Environment variable configuration with CONFIG_FILE_ support for INI files
- Automated updates, backups, and scheduled operations

---

## Development Setup

### Devcontainer

The project uses VS Code devcontainer with Docker-in-Docker.

**Setup:**
1. Open repository in VS Code
2. Click "Reopen in Container" when prompted
3. Wait for devcontainer to build
4. Verify Docker: `docker --version`

**Development Commands:**
```bash
# Build image
docker build -t vein-server:dev .

# Run container
docker compose up

# View logs
docker logs -f vein-server

# Shell into container
docker exec -it vein-server bash

# Check supervisord status
docker exec vein-server supervisorctl status

# Lint scripts
shellcheck bin/*.sh
```

---

## Architecture

### Finite State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTAINER START                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  system-bootstrap.sh (ENTRYPOINT - PID 1)                       │
│  - Setup cron jobs from ENV vars                                │
│  - Trap SIGTERM for graceful shutdown                           │
│  - Start supervisord                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  supervisord                                                     │
│  - Starts crond (priority 10, autostart=true)                   │
│  - Starts vein-bootstrap (priority 20, autostart=true)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  vein-bootstrap.sh                                              │
│  - Generate Game.ini from ENV vars (config_from_env_vars)       │
│  - Check if server files exist                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
        No server files                 Server files exist
              │                               │
              ▼                               │
┌──────────────────────┐                      │
│  vein-updater.sh     │                      │
│  - Run SteamCMD      │                      │
│  - App ID: 2131400   │                      ▼
│  - Launch server     │        ┌─────────────────────────┐
└──────────────────────┘        │  UPDATE_ON_BOOT check   │
              │                 └─────────────────────────┘
              │                       │         │
              │                 True  │         │  False
              │                       ▼         ▼
              │             ┌──────────────┐  ┌──────────────┐
              │             │vein-updater  │  │vein-server   │
              └────────────►│- Update files│  │- Start server│
                            │- Start server│  └──────────────┘
                            └──────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER RUNNING                                │
│  Cron triggers (if enabled):                                    │
│  - SCHEDULED_RESTART → stop server → vein-backup-and-restart    │
│  - SCHEDULED_UPDATE → supervisorctl start vein-updater          │
│  - SCHEDULED_BACKUP → stop server → vein-backup-and-restart     │
│    (Note: Scheduled backups also restart the server)            │
└─────────────────────────────────────────────────────────────────┘
                              │
                         SIGTERM
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  system-bootstrap.sh cleanup()                                  │
│  - supervisorctl stop all                                       │
│  - If BACKUP_ON_STOP=True → supervisorctl start vein-backup     │
│  - Wait for backup (max 600s)                                   │
│  - supervisorctl exit                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Supervisord Processes

| Process | Priority | Autostart | Purpose |
|---------|----------|-----------|---------|
| crond | 10 | true | Scheduled operations |
| vein-bootstrap | 20 | true | Config generation, state routing |
| vein-updater | 30 | false | SteamCMD updates |
| vein-server | 50 | false | Game server |
| vein-backup | 100 | false | Backup operations |
| vein-backup-and-restart | 100 | false | Backup then restart |
| vein-backup-and-update | 100 | false | Backup then update |

---

## Directory Structure

### Repository
```
vein-server/
├── Dockerfile
├── README.md
├── CLAUDE.md
├── LICENSE
├── CONTRIBUTING.md
├── .releaserc.yaml
├── package.json
├── .devcontainer/
├── .github/workflows/
├── bin/                          # Runtime scripts
│   ├── system-bootstrap.sh       # PID 1, signal handling
│   ├── vein-bootstrap.sh         # Config generation, routing
│   ├── vein-updater.sh           # SteamCMD manager
│   ├── vein-server.sh            # Server runner
│   └── vein-backup.sh            # Backup manager
├── config_from_env_vars/         # Python config generator
├── supervisord/
└── deployment-examples/
```

### Container Runtime
```
/vein-server/
├── server/                       # VOLUME - Game files
│   ├── VeinServer.sh
│   └── Vein/Saved/Config/LinuxServer/
├── logs/                         # VOLUME - Logs
├── backups/                      # VOLUME - Backups
├── bin/
└── supervisord/
```

---

## Scripts

### system-bootstrap.sh
- PID 1 entrypoint
- Signal handling (SIGTERM only)
- Cron job setup
- Graceful shutdown with backup

### vein-bootstrap.sh
- Generate Game.ini from ENV vars
- Route to vein-updater or vein-server based on UPDATE_ON_BOOT

### vein-updater.sh
- Run SteamCMD (App ID: 2131400)
- Trigger pre-update backup if enabled
- Start vein-server on completion

### vein-server.sh
- Execute VeinServer.sh as background process
- Wait for server process to complete

### vein-backup.sh
- Backup Vein/Saved directory
- Support tar.gz or ZIP
- Retention policy enforcement
- Variants: standalone, with-restart, with-update

### config_from_env_vars/main.py
- Parse CONFIG_FILE_ environment variables
- Generate INI files
- Format: `CONFIG_FILE_<filename>_SECTION_<section>_VAR_<variable>=<value>`

---

## Environment Variables

### Server Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_SERVER_NAME` | "Vein Server" | Server name |
| `VEIN_SERVER_DESCRIPTION` | "A Vein dedicated server" | Server description |
| `VEIN_SERVER_PASSWORD` | "" | Server password |
| `VEIN_SERVER_PUBLIC` | "True" | Show in browser |
| `VEIN_SERVER_MAX_PLAYERS` | 16 | Max players |
| `VEIN_SERVER_PORT` | 7777 | Game port (UDP) |
| `VEIN_SERVER_QUERY_PORT` | 27015 | Query port (UDP) |
| `VEIN_BIND_ADDR` | "0.0.0.0" | Bind address |
| `VEIN_HEARTBEAT_INTERVAL` | "5.0" | Heartbeat interval |
| `VEIN_VAC_ENABLED` | "0" | Enable VAC (Valve Anti-Cheat) |

### Update Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_ON_BOOT` | True | Update on container start |
| `SKIP_FILE_VALIDATION` | False | Skip SteamCMD file validation (faster updates) |
| `EXPERIMENTAL_BUILD` | False | Use experimental build (App ID: 2600250) |
| `MANUAL_CONFIG` | False | Skip config generation |

### Backup Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ON_STOP` | True | Backup on shutdown |
| `BACKUP_BEFORE_UPDATE` | True | Backup before updates |
| `BACKUP_ON_SCHEDULED_RESTART` | False | Backup before restarts |
| `SCHEDULED_BACKUP` | False | Enable scheduled backups |
| `BACKUP_CRON` | "0 6 * * *" | Backup schedule |
| `ZIP_BACKUPS` | False | Use ZIP instead of tar.gz |
| `RETAIN_BACKUPS` | "" | Backups to keep |

### Scheduling Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `SCHEDULED_RESTART` | False | Enable restarts |
| `RESTART_CRON` | "0 4 * * *" | Restart schedule |
| `SERVER_RESTART_DELAY` | 20 | Seconds to wait after stop before starting server (prevents SteamAPI init failures). Set to 0 or lower to disable. |
| `SCHEDULED_UPDATE` | False | Enable updates |
| `UPDATE_CRON` | "0 3 * * *" | Update schedule |

### System Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | (not set) | Enable verbose debug output in all shell scripts |

### Advanced Configuration (CONFIG_FILE_ Variables)

The CONFIG_FILE_ system allows generating custom INI files from environment variables.

**Format:** `CONFIG_FILE_<filename>_SECTION_<section>_VAR_<variable>=<value>`

**Transformation Process:**
1. Split on `_SECTION_` to extract filename
2. Split on `_VAR_` to separate section and variable names
3. Replace special character placeholders:
   - `SLASH` (with surrounding underscores) → `/`
   - `DOT` (with surrounding underscores) → `.`
4. Convert trailing numbers to array syntax: `Variable7` → `Variable[7]`

**Example Transformations:**

```bash
# Simple variable
Input:  CONFIG_FILE_Game_SECTION_ServerSettings_VAR_MaxPlayers=32
Output: Game.ini
        [ServerSettings]
        MaxPlayers=32

# Variable with dots (use DOT placeholder)
Input:  CONFIG_FILE_Engine_SECTION_ConsoleVariables_VAR_vein_DOT_PvP=True
Output: Engine.ini
        [ConsoleVariables]
        vein.PvP=True

# Section with slashes and dots
Input:  CONFIG_FILE_Game_SECTION_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_VAR_AdminSteamIDs=12345678901234567
Output: Game.ini
        [/Script/Vein.VeinGameSession]
        AdminSteamIDs=12345678901234567

# Array-style variable (trailing number becomes [N])
Input:  CONFIG_FILE_Game_SECTION_ServerSettings_VAR_PlayerBaseStatsMultipliers7=6.0
Output: Game.ini
        [ServerSettings]
        PlayerBaseStatsMultipliers[7]=6.0
```

**Docker Compose Example:**
```yaml
environment:
  CONFIG_FILE_Engine_SECTION_ConsoleVariables_VAR_vein_DOT_PvP: "True"
  CONFIG_FILE_Engine_SECTION_ConsoleVariables_VAR_vein_DOT_TimeMultiplier: "16"
  CONFIG_FILE_Game_SECTION_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_VAR_AdminSteamIDs: "12345678901234567"
```

---

## Container Configuration

### Exposed Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 7777 | UDP | Game server port (configurable via `VEIN_SERVER_PORT`) |
| 27015 | UDP | Query port (configurable via `VEIN_SERVER_QUERY_PORT`) |

### Health Check

The container includes a health check that monitors the supervisord process:

```dockerfile
HEALTHCHECK --interval=60s --timeout=10s --start-period=300s --retries=3
```

- **Interval:** Checks every 60 seconds
- **Timeout:** 10 seconds per check
- **Start Period:** 5 minutes grace period for initial startup
- **Retries:** 3 consecutive failures before marking unhealthy
- **Check:** Verifies supervisord process is running

---

## Common Tasks

### Debugging
```bash
docker exec -it vein-server bash
docker exec vein-server supervisorctl status
docker exec vein-server cat /vein-server/logs/bootstrap.log
docker exec vein-server env | grep VEIN_
```

### Manual Operations
```bash
# Trigger backup
docker exec vein-server supervisorctl start vein-backup

# Trigger update
docker exec vein-server supervisorctl start vein-updater

# Restart server
docker exec vein-server supervisorctl restart vein-server
```

### Testing
```bash
shellcheck bin/*.sh
docker build -t vein-server:dev .
```

---

## Troubleshooting

### Server Fails to Start

**Check logs:**
```bash
docker exec vein-server cat /vein-server/logs/bootstrap.log
docker logs vein-server
```

**Verify server files exist:**
```bash
docker exec vein-server ls -la /vein-server/server/VeinServer.sh
```

**Check supervisord status:**
```bash
docker exec vein-server supervisorctl status
```

### SteamAPI Initialization Failures

If you see "SteamAPI initialization failed" errors:

1. Increase the restart delay:
   ```yaml
   environment:
     SERVER_RESTART_DELAY: 30  # Increase from default 20
   ```

2. Verify SteamCMD completed successfully:
   ```bash
   docker exec vein-server cat /vein-server/logs/updater.log
   ```

### Configuration Changes Not Applied

**Verify MANUAL_CONFIG is not enabled:**
```bash
docker exec vein-server env | grep MANUAL_CONFIG
```

**Check if config files were generated:**
```bash
docker exec vein-server ls -la /vein-server/server/Vein/Saved/Config/LinuxServer/
```

**Regenerate config files:**
```bash
# Set MANUAL_CONFIG=False and restart container
docker restart vein-server
```

### Updates Not Working

**Check updater logs:**
```bash
docker exec vein-server cat /vein-server/logs/updater.log
```

**Manually trigger update:**
```bash
docker exec vein-server supervisorctl start vein-updater
docker exec vein-server supervisorctl tail -f vein-updater
```

**Skip file validation for faster updates:**
```yaml
environment:
  SKIP_FILE_VALIDATION: "True"
```

### Scheduled Tasks Not Running

**Verify cron jobs are configured:**
```bash
docker exec vein-server crontab -l
```

**Check cron logs:**
```bash
docker exec vein-server grep CRON /var/log/syslog
```

**Enable scheduled operations:**
```yaml
environment:
  SCHEDULED_RESTART: "True"
  RESTART_CRON: "0 4 * * *"
```

### Enable Debug Mode

For verbose output in all scripts:
```yaml
environment:
  DEBUG: "true"
```

Then restart and check logs:
```bash
docker restart vein-server
docker logs -f vein-server
```

---

## Key Differences from ark-sa-server

| Aspect | ARK-SA-Server | Vein Server |
|--------|---------------|-------------|
| Platform | Windows via Wine | Native Linux |
| App ID | 2430930 | 2131400 |
| Startup | Wine + .exe | ./VeinServer.sh |
| Config Path | WindowsServer/ | LinuxServer/ |
| Config Files | GameUserSettings.ini | Game.ini |

---

## Git Workflow

### Branches
- `main` - Production releases
- `next` - Integration branch

### Branch Naming
- `feat/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation
- `chore/*` - Maintenance

### Conventional Commits
```
feat: add backup retention policy
fix: correct healthcheck timeout
docs: update README
chore: update dependencies
```

---

## License

MIT License
