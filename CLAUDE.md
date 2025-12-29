# CLAUDE.md - Vein Game Server Docker Container

## Project Overview

Docker containerization solution for running Vein dedicated game servers, based on the architecture and patterns from [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server).

**Key Features:**
- Supervisord-based finite state machine for process orchestration
- Native Linux server (no Wine/Proton required)
- Environment variable configuration with CONFIG_ support for INI files
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
docker-compose up

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
│  - Trap SIGTERM/SIGINT for graceful shutdown                    │
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
    No files OR                      Files exist AND
    UPDATE_ON_BOOT=True              UPDATE_ON_BOOT=False
              │                               │
              ▼                               ▼
┌──────────────────────┐          ┌──────────────────────┐
│  vein-updater.sh     │          │  vein-server.sh      │
│  - Run SteamCMD      │          │  - Run VeinServer.sh │
│  - App ID: 2131400   │          │  - Exec in foreground│
└──────────────────────┘          └──────────────────────┘
              │                               │
              ▼                               │
┌──────────────────────┐                      │
│  vein-server.sh      │◄─────────────────────┘
│  - Run VeinServer.sh │
└──────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SERVER RUNNING                                │
│  Cron triggers (if enabled):                                    │
│  - SCHEDULED_RESTART → supervisorctl restart vein-server        │
│  - SCHEDULED_UPDATE → supervisorctl start vein-updater          │
│  - SCHEDULED_BACKUP → supervisorctl start vein-backup           │
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
- Signal handling (SIGTERM, SIGINT)
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
- Execute VeinServer.sh
- Tail logs to stdout

### vein-backup.sh
- Backup Vein/Saved directory
- Support tar.gz or ZIP
- Retention policy enforcement
- Variants: standalone, with-restart, with-update

### config_from_env_vars/main.py
- Parse CONFIG_ environment variables
- Generate INI files
- Handle SLASH (/) and DOT (.) replacements

---

## Environment Variables

### Server Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_SERVER_NAME` | "Vein Server" | Server name |
| `VEIN_SERVER_PASSWORD` | "" | Server password |
| `VEIN_SERVER_PUBLIC` | "True" | Show in browser |
| `VEIN_SERVER_MAX_PLAYERS` | 16 | Max players |
| `VEIN_SERVER_PORT` | 7777 | Game port |
| `VEIN_SERVER_QUERY_PORT` | 27015 | Query port |

### Update Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_ON_BOOT` | True | Update on container start |
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
| `SCHEDULED_UPDATE` | False | Enable updates |
| `UPDATE_CRON` | "0 3 * * *" | Update schedule |

### Advanced Configuration (CONFIG_ Variables)

Format: `CONFIG_<filename>_<section>_<variable>=<value>`
- Use `SLASH` for `/`
- Use `DOT` for `.`

Example:
```yaml
CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_AdminSteamIDs: "76561198012345678"
```

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
