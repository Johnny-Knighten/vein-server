# CLAUDE.md - Vein Game Server Docker Container

## Project Overview

This project creates a Docker containerization solution for running Vein dedicated game servers, based on the architecture and patterns established in the [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server) project.

**Key Objectives:**
- Achieve feature parity with ark-sa-server
- Adapt supervisord-based finite state machine for Vein
- Leverage Vein's native Linux server (simpler than ARK's Wine/Proton requirement)
- Support 251+ Vein console variables via environment-based configuration
- Provide automated updates, backups, and scheduled operations

---

## Development Setup

### Devcontainer Configuration

The project uses VS Code devcontainer with Docker-in-Docker for local development and testing.

**Key Features:**
- Base image: `mcr.microsoft.com/devcontainers/base:bookworm`
- Docker-in-Docker feature for building and testing containers
- Port forwarding: 7777 (game), 27015 (query)
- Development tools: shellcheck, shfmt, git, gh CLI

**Setup:**
1. Open repository in VS Code
2. Click "Reopen in Container" when prompted
3. Wait for devcontainer to build and install dependencies
4. Verify Docker is available: `docker --version`

**Development Workflow:**
```bash
# Build Docker image
docker build -t vein-server:dev .

# Run with docker-compose
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

### Finite State Machine Design

The container uses supervisord to orchestrate a finite state machine through sequential process execution:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Container Lifecycle                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌──────────────────┐
                    │ system-bootstrap │ ← PID 1
                    │  (Signal Handler)│
                    └──────────────────┘
                              ↓
                    Start supervisord
                              ↓
                    ┌──────────────────┐
                    │  vein-bootstrap  │ ← State Router
                    └──────────────────┘
                              ↓
              ┌───────────────┴───────────────┐
              ↓                               ↓
    ┌──────────────────┐          ┌──────────────────┐
    │  vein-updater    │          │   vein-server    │
    │ (if update needed│          │  (if up-to-date) │
    └──────────────────┘          └──────────────────┘
              ↓                               ↓
    Download via SteamCMD              Running Server
    Validate files                     Monitor logs
    Trigger backup first               Health checks
              ↓                               ↓
    ┌──────────────────┐                     │
    │   vein-server    │←────────────────────┘
    │  (post-update)   │
    └──────────────────┘
              ↓
    ┌─────────────────────────────────────────┐
    │         Server Running                   │
    │  - Process monitoring                    │
    │  - Health checks                         │
    │  - Crash recovery                        │
    └─────────────────────────────────────────┘
              ↓
    ┌──────────────────────────────────────────┐
    │     Event-Driven State Transitions        │
    └──────────────────────────────────────────┘
       ↓              ↓              ↓
   Scheduled      Scheduled      Scheduled
    Restart        Update         Backup
       ↓              ↓              ↓
   Stop server   Stop server    Create backup
       ↓              ↓              ↓
   Backup        Backup         Continue
       ↓              ↓           running
   Restart       Update
       ↓              ↓
   Start         Restart
```

### Supervisord Process Hierarchy

```
supervisord (process manager)
├── crond (priority 10)
│   └── Executes scheduled operations
│
├── vein-bootstrap (priority 20, autostart=true, autorestart=false)
│   ├── Generate configs from ENV vars
│   ├── Validate server files
│   ├── Route to updater or server
│   └── Exit after routing
│
├── vein-updater (priority 30, autostart=false)
│   ├── Trigger pre-update backup
│   ├── Run SteamCMD (App ID: 2131400)
│   ├── Validate installation
│   └── Start vein-server on completion
│
├── vein-server (priority 50, autostart=false)
│   ├── Execute ./VeinServer.sh -log
│   ├── Monitor logs for startup success
│   ├── Health check integration
│   └── Crash detection/recovery
│
├── vein-backup (priority 100, autostart=false)
│   ├── Standalone backup triggered manually or by cron
│   ├── 600s timeout
│   └── Backup entire Vein/Saved directory
│
├── vein-backup-and-restart (priority 100, autostart=false)
│   ├── Backup then restart server
│   ├── 600s timeout
│   └── Used by scheduled restart with backup
│
└── vein-backup-and-update (priority 100, autostart=false)
    ├── Backup then trigger update
    ├── 600s timeout
    └── Used by scheduled update with backup
```

**Key Design Principles:**
- Only one core process (bootstrap/updater/server) active at a time
- State transitions via supervisorctl commands
- Backup processes are non-destructive (autostart=false, autorestart=false)
- Event-driven architecture (cron, container lifecycle, process completion)

---

## Directory Structure

### Repository Structure

```
vein-server/
├── Dockerfile                              # Container image definition
├── docker-compose.yml                      # Primary deployment method
├── .dockerignore                          # Build context optimization
├── .gitignore                             # Git ignore patterns
├── README.md                              # User-facing documentation
├── CLAUDE.md                              # This file - AI assistant context
├── LICENSE                                # MIT License
├── CONTRIBUTING.md                        # Contribution guidelines
├── .releaserc.yaml                        # Semantic-release config
├── package.json                           # Node.js dependencies for release
│
├── .devcontainer/
│   ├── devcontainer.json                  # Docker-in-Docker config
│   └── post-create.sh                     # Dev tools setup script
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug-report.md                  # Bug report template
│   │   └── feature-request.md             # Feature request template
│   ├── pull_request_template.md           # PR template
│   └── workflows/
│       ├── build-and-test.yml             # CI workflow
│       └── release.yml                    # Release workflow
│
├── bin/                                   # Runtime scripts
│   ├── system-bootstrap.sh                # PID 1 entrypoint, cron setup
│   ├── vein-bootstrap.sh                  # State router, config generator
│   ├── vein-updater.sh                    # SteamCMD manager
│   ├── vein-server.sh                     # Server runner
│   └── vein-backup.sh                     # Backup manager (all variants)
│
├── config_from_env_vars/                  # Python config generator
│   ├── __init__.py
│   └── main.py                            # ENV → INI converter
│
├── supervisord/
│   └── supervisord.conf                   # Process orchestration
│
├── deployment-examples/
│   ├── README.md
│   └── docker-compose/
│       ├── README.md
│       ├── basic-docker-compose.yml       # Minimal setup
│       └── advanced-docker-compose.yml    # All features
│
└── docs/
    └── IMPLEMENTATION_PLAN.md             # Development plan
```

### Container Runtime Structure

```
/vein-server/                              # Container root
├── server/                                # VOLUME - Game files
│   ├── VeinServer.sh                     # Server startup script
│   ├── Vein/
│   │   ├── Binaries/Linux/               # Native Linux binaries
│   │   ├── Content/                      # Game content
│   │   └── Saved/
│   │       ├── Config/LinuxServer/       # Configuration
│   │       │   ├── Game.ini             # Main config (generated)
│   │       │   └── Engine.ini           # Engine config (generated)
│   │       └── SaveGames/
│   │           └── Server.vns           # Save file (5-min overwrite)
│   └── steamapps/                        # SteamCMD metadata
│
├── logs/                                  # VOLUME - Log files
│   ├── bootstrap.log
│   ├── updater.log
│   ├── server.log
│   ├── backup.log
│   ├── cron.log
│   ├── monitor.log
│   └── supervisord.log
│
├── backups/                               # VOLUME - Backup archives
│   └── vein-backup-2025-01-15-04-00-00.tar.gz
│
├── bin/                                   # Runtime scripts
└── supervisord/                           # Supervisord config
```

---

## Script Responsibilities

### system-bootstrap.sh
**Role:** Container PID 1, signal handler, graceful shutdown orchestrator

**Responsibilities:**
- Run as PID 1 to receive Docker signals
- Trap SIGTERM and SIGINT for graceful shutdown
- Initialize supervisord
- On shutdown:
  1. Stop all supervisord processes
  2. Trigger final backup (vein-backup-on-stop)
  3. Wait for backup completion (600s max)
  4. Shutdown supervisord

**Key Functions:**
```bash
cleanup() {
    log "Received shutdown signal, initiating graceful shutdown"
    supervisorctl stop all
    supervisorctl start vein-backup-on-stop
    wait_for_backup_completion
    supervisorctl shutdown
}
```

### vein-bootstrap.sh
**Role:** State router, configuration generator, validator

**Responsibilities:**
- Generate Game.ini and Engine.ini from ENV vars (via Python config_from_env_vars)
- Validate required files exist (VeinServer.sh, binaries)
- Decide state transition:
  - If `UPDATE_ON_BOOT=True` → start vein-updater
  - If `UPDATE_ON_BOOT=False` → start vein-server directly
- Log all decisions
- Exit after routing (autorestart=false)

### vein-updater.sh
**Role:** SteamCMD update manager

**Responsibilities:**
- Trigger pre-update backup if `VEIN_BACKUP_PRE_UPDATE=true`
- Run SteamCMD with App ID 2131400
- Validate installation (check VeinServer.sh executable exists)
- Start vein-server on successful update
- Exit on completion

**SteamCMD Command:**
```bash
steamcmd +force_install_dir /vein-server/server \
         +login anonymous \
         +app_update 2131400 validate \
         +quit
```

### vein-server.sh
**Role:** Game server runner, log monitor

**Responsibilities:**
- Execute `./VeinServer.sh -log` in server directory
- Monitor startup success (parse logs for "Server ready" or similar)
- Tail logs to stdout for `docker logs` visibility
- Cleanup on exit
- Integrate with health check

**Startup Detection:**
- Watch for VeinServer.sh process
- Monitor log file creation
- 300s startup timeout

### vein-backup.sh
**Role:** Backup manager for all backup scenarios

**Responsibilities:**
- Backup entire `Vein/Saved` directory (includes Server.vns + configs)
- Support tar.gz or ZIP compression
- Timestamped naming: `vein-backup-YYYY-MM-DD-HH-MM-SS.tar.gz`
- Retention policy enforcement (delete old backups)
- Backup verification (test archive integrity)
- 600s timeout protection
- Three variants: on-stop, scheduled, pre-update

**Critical Note:** Vein's Server.vns overwrites every 5 minutes. Pre-update backup is essential.

### config_from_env_vars/main.py
**Role:** Python-based ENV var → INI file converter (from ark-sa-server)

**Responsibilities:**
- Parse ENV vars with `CONFIG_` prefix
- Generate INI files in `Vein/Saved/Config/LinuxServer/`
- Handle special characters: `SLASH` → `/`, `DOT` → `.`
- Automatic backup of existing configs
- Case-preserving INI parsing

**Example:**
```bash
# ENV var: CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_MaxPlayers=32
# Maps to Game.ini:
# [/Script/Vein.VeinGameSession]
# MaxPlayers=32
```

**Note:** Cron setup is handled directly in system-bootstrap.sh (matching ark-sa-server pattern).
Scheduled operations use supervisorctl commands directly from cron, not separate handler scripts.

---

## Environment Variables Reference

### Core Server Settings

**Phase 3 Complete:** Configuration system uses Python-based ENV → INI conversion (ark-sa-server method)

| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_SERVER_NAME` | "Vein Server" | Server name shown in browser |
| `VEIN_SERVER_DESCRIPTION` | "A Vein dedicated server" | Server description/MOTD |
| `VEIN_SERVER_PASSWORD` | "" | Server password (empty = no password) |
| `VEIN_SERVER_PUBLIC` | "True" | Show in server browser (True/False) |
| `VEIN_SERVER_MAX_PLAYERS` | 16 | Maximum players (Vein default) |
| `VEIN_SERVER_PORT` | 7777 | Game port (UDP) |
| `VEIN_SERVER_QUERY_PORT` | 27015 | Query port (UDP) |
| `VEIN_BIND_ADDR` | "0.0.0.0" | IP address to bind |
| `VEIN_HEARTBEAT_INTERVAL` | "5.0" | Heartbeat interval (seconds) |
| `VEIN_VAC_ENABLED` | "0" | Enable Steam VAC (0=disabled, 1=enabled) |

### Update Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_AUTO_UPDATE` | true | Auto-update on container start |
| `VEIN_VALIDATE_FILES` | true | Validate files after update |
| `VEIN_UPDATE_ON_START` | true | Check for updates on first run |

### Backup Settings

**NOTE:** Backup variables match ark-sa-server pattern (NO `VEIN_` prefix - system-level settings)

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ON_STOP` | True | Create backup on container shutdown/SIGTERM |
| `BACKUP_ON_SCHEDULED_RESTART` | False | Create backup before scheduled restarts |
| `BACKUP_BEFORE_UPDATE` | True | Create backup before SteamCMD update (Vein default: True due to Server.vns overwrite) |
| `SCHEDULED_BACKUP` | False | Enable standalone scheduled backup jobs |
| `BACKUP_CRON` | "0 6 * * *" | Cron schedule for standalone backups (6 AM daily) |
| `ZIP_BACKUPS` | False | Use ZIP compression (False = tar.gz, True = ZIP) |
| `RETAIN_BACKUPS` | "" | Number of backups to keep (empty = unlimited) |

### Scheduling Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `SCHEDULED_RESTART` | False | Enable scheduled server restarts |
| `RESTART_CRON` | "0 4 * * *" | Restart schedule (4 AM daily) |
| `SCHEDULED_UPDATE` | False | Enable scheduled server updates |
| `UPDATE_CRON` | "0 3 * * *" | Update schedule (3 AM daily) |

### Advanced Configuration (CONFIG_ Variables)

**Phase 3 Feature:** Direct INI control for advanced users

For settings not covered by simple ENV vars, use `CONFIG_` variables to directly control Game.ini:

**Format:** `CONFIG_<filename>_<section>_<variable>=<value>`
- Use `SLASH` for `/` in section names
- Use `DOT` for `.` in section names

**Examples:**

| CONFIG_ Variable | Maps To | Description |
|------------------|---------|-------------|
| `CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_AdminSteamIDs` | `[/Script/Vein.VeinGameSession]` → `AdminSteamIDs` | Admin Steam IDs |
| `CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_SuperAdminSteamIDs` | `[/Script/Vein.VeinGameSession]` → `SuperAdminSteamIDs` | Super admin Steam IDs |
| `CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameStateBase_WhitelistedPlayers` | `[/Script/Vein.VeinGameStateBase]` → `WhitelistedPlayers` | Server whitelist |

**Multiple Values:** For array-style values (like multiple admin IDs), use `+` prefix in Vein's Game.ini:
```ini
AdminSteamIDs=76561198012345678
+AdminSteamIDs=76561198087654321
```

**Note:** CONFIG_ variables bypass bootstrap transformation and directly set INI values. See official Vein documentation for all available Game.ini settings.

### Health Check Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VEIN_HEALTH_CHECK_ENABLED` | true | Enable Docker healthcheck (future) |
| `VEIN_RESTART_ON_CRASH` | true | Auto-restart on crash (future) |
| `VEIN_CRASH_RESTART_DELAY` | 60 | Delay before restart (seconds, future) |

### Manual Configuration Mode

| Variable | Default | Description |
|----------|---------|-------------|
| `MANUAL_CONFIG` | "False" | Set to "True" to skip automatic config generation and use your own Game.ini/Engine.ini files |

---

## Common Development Tasks

### Building the Image

```bash
# Development build
docker build -t vein-server:dev .

# Production build with tag
docker build -t vein-server:v1.0.0 .

# Build without cache
docker build --no-cache -t vein-server:dev .
```

### Running Locally

```bash
# Foreground with logs
docker-compose up

# Background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v
```

### Testing Scripts

```bash
# Lint all scripts
shellcheck bin/*.sh

# Format scripts
shfmt -i 2 -ci -w bin/*.sh

# Test individual script
bash -n bin/vein-bootstrap.sh  # syntax check
bash -x bin/vein-bootstrap.sh  # debug mode
```

### Debugging Container

```bash
# Shell into running container
docker exec -it vein-server bash

# Check supervisord status
docker exec vein-server supervisorctl status

# View specific process log
docker exec vein-server tail -f /vein-server/logs/server.log

# Manually trigger operations
docker exec vein-server supervisorctl start vein-backup-scheduled
docker exec vein-server supervisorctl start vein-updater

# Check cron jobs
docker exec vein-server crontab -l

# View environment variables
docker exec vein-server env | grep VEIN_
```

### Manual Testing Checklist

**Phase 1 (MVP):**
- [ ] Build succeeds without errors
- [ ] SteamCMD downloads server files
- [ ] Server starts and binds to port 7777
- [ ] Query port 27015 responds
- [ ] Logs visible via `docker logs`
- [ ] Graceful shutdown works (Ctrl+C)
- [ ] Data persists across restarts

**Phase 2 (Updates):**
- [ ] Auto-update runs on first start
- [ ] Update can be disabled via ENV
- [ ] File validation detects missing files
- [ ] State transitions logged correctly

**Phase 3 (Config):**
- [ ] ENV vars generate correct INI files
- [ ] Presets load successfully
- [ ] Config changes apply on restart
- [ ] Invalid values use defaults

**Phase 4 (Backups):**
- [ ] Backup created on shutdown
- [ ] Pre-update backup works
- [ ] Retention policy deletes old backups
- [ ] Backups can be restored

**Phase 5 (Scheduling):**
- [ ] Cron jobs execute on schedule
- [ ] Scheduled restart is graceful
- [ ] Scheduled update triggers backup

**Phase 6 (Monitoring):**
- [ ] Health check shows "healthy"
- [ ] Crashes trigger auto-restart
- [ ] Crash loops prevented

**Phase 7 (Documentation):**
- [ ] README quick start works
- [ ] Examples copy-paste correctly
- [ ] All ENV vars documented

---

## Testing Procedures

### Unit Testing (Scripts)

```bash
# Run shellcheck on all scripts
shellcheck bin/*.sh

# Python config tests
cd config_from_env_vars
python -m pytest test_main.py -v
```

### Integration Testing

```bash
# Test full lifecycle
docker-compose up -d
sleep 300  # Wait for server startup
docker exec vein-server supervisorctl status
docker-compose down

# Test update system
docker-compose up -d
docker exec vein-server supervisorctl start vein-updater
# Watch for completion
docker exec vein-server tail -f /vein-server/logs/updater.log

# Test backup system
docker exec vein-server supervisorctl start vein-backup-scheduled
ls -lh /path/to/backups

# Test scheduled operations
# Edit docker-compose.yml: VEIN_BACKUP_CRON=* * * * *  (every minute)
docker-compose up -d
# Wait 2 minutes, check for backups
```

### Performance Testing

```bash
# Monitor resource usage
docker stats vein-server

# Check disk usage
docker exec vein-server df -h

# Monitor memory
docker exec vein-server free -h

# Check process count
docker exec vein-server ps aux | wc -l
```

---

## Troubleshooting Tips

### Server Won't Start

**Symptoms:** Container exits immediately or supervisord shows FATAL state

**Checks:**
```bash
# View bootstrap logs
docker logs vein-server

# Check supervisord logs
docker exec vein-server cat /vein-server/logs/supervisord.log

# Check disk space
docker exec vein-server df -h

# Verify VeinServer.sh exists
docker exec vein-server ls -la /vein-server/server/VeinServer.sh
```

### Configuration Not Applying

**Symptoms:** Server ignores ENV vars

**Checks:**
```bash
# Verify ENV vars in container
docker exec vein-server env | grep VEIN_

# Check generated INI files
docker exec vein-server cat /vein-server/server/Vein/Saved/Config/LinuxServer/Game.ini

# Check bootstrap logs for config generation
docker exec vein-server cat /vein-server/logs/bootstrap.log
```

### Backups Failing

**Symptoms:** No backups created, timeout errors

**Checks:**
```bash
# Check backup logs
docker exec vein-server cat /vein-server/logs/backup.log

# Check disk space
docker exec vein-server df -h /vein-server/backups

# Manually trigger backup
docker exec vein-server supervisorctl start vein-backup-scheduled

# Check backup process status
docker exec vein-server supervisorctl status vein-backup-scheduled
```

### Cron Jobs Not Running

**Symptoms:** Scheduled operations don't execute

**Checks:**
```bash
# Verify cron is running
docker exec vein-server ps aux | grep cron

# Check crontab
docker exec vein-server crontab -l

# Check cron logs
docker exec vein-server cat /vein-server/logs/cron.log

# Check supervisord crond process
docker exec vein-server supervisorctl status crond
```

---

## Feature Parity Checklist with ark-sa-server

### ✅ Core Features

- [ ] Supervisord process orchestration
- [ ] Finite state machine (bootstrap → updater → server)
- [ ] PID 1 signal handling (SIGTERM, SIGINT)
- [ ] Graceful shutdown with cleanup
- [ ] SteamCMD integration
- [ ] Automatic server updates
- [ ] File validation after updates

### ✅ Configuration Management

- [ ] ENV var → INI file generation
- [ ] Template-based configuration
- [ ] Default value handling
- [ ] Configuration presets (default, PvE, PvP)
- [ ] Validation for required settings

### ✅ Backup System

- [ ] On-stop backups
- [ ] Pre-update backups
- [ ] Scheduled backups
- [ ] Retention policy management
- [ ] tar.gz compression
- [ ] ZIP compression option
- [ ] Backup verification
- [ ] 600s timeout protection

### ✅ Scheduled Operations

- [ ] Cron-based scheduling
- [ ] Scheduled server restarts
- [ ] Scheduled updates
- [ ] Scheduled backups
- [ ] Pre-restart warnings (log-based)
- [ ] Lock file prevents concurrent operations

### ✅ Monitoring & Health

- [ ] Docker HEALTHCHECK
- [ ] Startup detection
- [ ] Crash detection
- [ ] Automatic restart on crash
- [ ] Exponential backoff for crash loops
- [ ] Error pattern detection
- [ ] Process state monitoring

### ✅ Documentation

- [ ] Comprehensive README
- [ ] ENV var reference table
- [ ] Quick start guide
- [ ] Example docker-compose files
- [ ] Troubleshooting section
- [ ] CLAUDE.md for AI assistance

### ✅ Vein-Specific Adaptations

- [ ] Native Linux execution (no Wine/Proton)
- [ ] 251+ console variable support
- [ ] LinuxServer/ config path
- [ ] Single save file backup (Server.vns)
- [ ] Game.ini + Engine.ini generation
- [ ] Configuration categories (PvP, zombies, time, loot, performance)

---

## Implementation Phases Summary

### Phase 1: MVP (Week 1) - 8 PRs
- PR 1.1: Project foundation & devcontainer
- PR 1.2: Docker foundation (Dockerfile + Compose)
- PR 1.3: Common utilities & logging
- PR 1.4: Supervisord configuration
- PR 1.5: System bootstrap (PID 1)
- PR 1.6: Vein bootstrap (initial setup)
- PR 1.7: Vein server runner
- PR 1.8: Integration & E2E testing

### Phase 2: State Machine (Week 1-2) - 4 PRs
- PR 2.1: SteamCMD updater script
- PR 2.2: FSM routing in bootstrap
- PR 2.3: Supervisord process integration
- PR 2.4: Integration & E2E testing

### Phase 3: Configuration (Week 2) - 5 PRs
- PR 3.1: Configuration templates
- PR 3.2: Configuration presets
- PR 3.3: Config generator script (core)
- PR 3.4: Config validation & advanced features
- PR 3.5: Bootstrap integration

### Phase 4: Backups (Week 2-3) - 6 PRs
- PR 4.1: Core backup script
- PR 4.2: Retention policy
- PR 4.3: Backup verification & ZIP support
- PR 4.4: On-stop backup trigger
- PR 4.5: Pre-update backup trigger
- PR 4.6: Integration & E2E testing

### Phase 5: Scheduling (Week 3) - 6 PRs
- PR 5.1: Cron setup script
- PR 5.2: Scheduled backup handler
- PR 5.3: Scheduled restart handler
- PR 5.4: Scheduled update handler
- PR 5.5: Supervisord crond integration
- PR 5.6: Integration & E2E testing

### Phase 6: Monitoring (Week 3-4) - 7 PRs
- PR 6.1: Startup detection in server runner
- PR 6.2: Docker healthcheck script
- PR 6.3: Dockerfile healthcheck directive
- PR 6.4: Process monitor script
- PR 6.5: Error pattern detection
- PR 6.6: Supervisord monitor integration
- PR 6.7: Integration & E2E testing

### Phase 7: Documentation (Week 4) - 7 PRs
- PR 7.1: MIT License
- PR 7.2: Example docker-compose files
- PR 7.3: CLAUDE.md
- PR 7.4: Comprehensive README (Part 1)
- PR 7.5: Comprehensive README (Part 2)
- PR 7.6: Comprehensive README (Part 3)
- PR 7.7: Release preparation

**Total: ~43 PRs across 7 phases**

**🎉 Feature Parity Achieved**

---

## Future Enhancements (Post-Parity)

### API Integration
- Vein API support (port 8080/TCP)
- In-game broadcast messages
- Player list and status queries
- Admin command execution

### CI/CD Pipeline
- GitHub Actions for automated builds
- Docker Hub publishing
- Shellcheck linting
- Multi-architecture builds

### Enhanced Documentation
- Separate docs/ directory
- Configuration reference (all 251+ variables)
- Troubleshooting guide
- Migration guide
- Performance tuning guide
- GitHub Wiki

### Community Features
- Issue and PR templates
- Contributing guidelines
- Code of conduct
- Additional presets

### Advanced Monitoring
- Prometheus metrics
- Grafana dashboards
- Discord webhooks
- Player activity tracking

### Cluster Support
- Multi-server clustering
- Shared save data
- Load balancing

---

## Key Differences: Vein vs ARK-SA-Server

| Aspect | ARK-SA-Server | Vein Server |
|--------|---------------|-------------|
| **Platform** | Windows via Wine/Proton | Native Linux |
| **App ID** | 2430930 | 2131400 |
| **Startup** | Wine + .exe + 45s delay | ./VeinServer.sh -log |
| **Config Files** | GameUserSettings.ini, Game.ini | Game.ini, Engine.ini |
| **Config Path** | WindowsServer/ | LinuxServer/ |
| **Save Files** | Multi-file .ark saves | Single Server.vns (5-min overwrite) |
| **Config Vars** | ~100 settings | 251+ console variables |
| **Admin** | RCON (port 27020) | In-game panel (\) + API (future) |
| **Complexity** | Higher (Wine layer) | Lower (native) |
| **Image Size** | Larger (Wine/Proton) | Smaller (no Wine) |

**Key Simplifications:**
- No Wine/Proton installation or management
- No Windows binary compatibility layer
- Simpler startup process
- Faster container startup

**Key Complexities:**
- More configuration variables (251+ vs ~100)
- Single save file (higher data loss risk)
- No RCON (requires alternative admin approach)

---

## Branch Strategy

### Long-Running Branches

1. **`main`** - Production releases only
   - Protected branch
   - Only receives merges from `next` via release PRs
   - Tagged with semantic versions (v1.0.0, v1.1.0, etc.)
   - Triggers Docker Hub builds

2. **`next`** - Integration and release preparation
   - Protected branch
   - Receives PRs for all features and fixes
   - Pre-release testing happens here
   - semantic-release prepares releases here

### Feature/Fix Branches

- **`feat/*`** - New features (e.g., `feat/backup-core`, `feat/config-templates`)
- **`fix/*`** - Bug fixes (e.g., `fix/healthcheck-timeout`, `fix/backup-retention`)
- **`docs/*`** - Documentation only (e.g., `docs/readme-part1`, `docs/claude-md`)
- **`chore/*`** - Maintenance tasks (e.g., `chore/release-prep`, `chore/deps-update`)

---

## Git Workflow

### For Each PR (Feature/Fix)

**1. Checkout and Rebase:**
```bash
git checkout main
git pull origin main
git checkout next
git pull origin next
git rebase main
```

**2. Create Feature Branch (from `next`):**
```bash
# From next branch
git checkout -b feat/feature-name
# or
git checkout -b fix/bug-name
# or
git checkout -b docs/documentation-name
```

**3. Develop and Commit:**
```bash
# Make changes
git add .
git commit -m "feat: add feature description"

# Follow conventional commits:
# - feat: new feature
# - fix: bug fix
# - docs: documentation
# - chore: maintenance
# - refactor: code refactoring
# - test: add tests
# - perf: performance improvements
```

**4. Lint and Test Locally:**
```bash
# Run shellcheck on all scripts
shellcheck bin/*.sh

# Build Docker image
docker build -t vein-server:dev .

# Test with docker-compose
docker-compose up

# Fix any issues before pushing
```

**5. Push and Open PR:**
```bash
# Push feature branch
git push origin feat/feature-name

# Open PR on GitHub:
# - Target: next branch
# - Title: feat: add feature description
# - Description: Details of changes, testing done, screenshots if applicable
```

**6. Merge and Cleanup:**
```bash
# After PR approved and merged to next:
git checkout next
git pull origin next
git branch -d feat/feature-name
```

### Release Workflow

**1. Prepare Release in `next`:**
```bash
# Ensure all features for release are merged to next
# Run semantic-release in next branch
# This generates changelog and bumps version
```

**2. Create Release PR: `next` → `main`:**
```bash
git checkout main
git pull origin main
git merge next
git push origin main

# semantic-release creates git tag automatically
# Docker Hub builds from tag
```

**3. Post-Release Sync:**
```bash
# Sync next with main
git checkout next
git merge main
git push origin next
```

---

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

**Feature:**
```
feat: add backup retention policy management
```

**Bug Fix:**
```
fix: correct healthcheck timeout logic in monitor script
```

**Documentation:**
```
docs: update README configuration section with new ENV vars
```

**Chore:**
```
chore: update shellcheck to v0.9.0
```

**Refactor:**
```
refactor: simplify config generator template replacement
```

**Test:**
```
test: add backup verification integration tests
```

**Performance:**
```
perf: optimize log parsing in server runner
```

**Breaking Changes:**
```
feat!: change ENV var naming convention

BREAKING CHANGE: All ENV vars now use VEIN_ prefix instead of GAME_.
Migration guide: Update docker-compose.yml to rename all GAME_* vars to VEIN_*.
```

---

## PR Strategy

Each unit of work = 1 PR, following these guidelines:

1. **Small, Focused PRs** - Each PR addresses one feature/fix/doc
2. **Clear Titles** - Use conventional commit format
3. **Detailed Descriptions** - Explain what, why, and how
4. **Testing Evidence** - Include test results, screenshots
5. **Target `next`** - All PRs merge to `next`, not `main`
6. **Review Ready** - Lint and test locally before opening PR

**Example PR Structure:**

**Title:** `feat: add backup retention policy management`

**Description:**
```markdown
## Summary
Implements backup retention policy to automatically delete old backups based on VEIN_BACKUP_RETENTION setting.

## Changes
- Add `cleanup_old_backups()` function to vein-backup.sh
- Add retention helpers to common-functions.sh
- Add VEIN_BACKUP_RETENTION ENV var (default: 10)
- Update docker-compose.yml with example

## Testing
- ✓ Shellcheck passes on modified scripts
- ✓ Created 15 test backups, retention=10 deletes 5 oldest
- ✓ Retention count respected across restarts
- ✓ Works with both tar.gz and ZIP formats

## Related Issues
Closes #12
```

---

## Contributing to Development

When working on this project:

1. **Follow branching strategy** - Always branch from `next`, PR to `next`
2. **Use conventional commits** - Enables automated versioning and changelogs
3. **Always test in devcontainer** - Ensures consistent environment
4. **Lint scripts before commit** - Run `shellcheck bin/*.sh`
5. **Test each PR independently** - Don't skip manual testing
6. **Update this CLAUDE.md** - Document new patterns and decisions
7. **Follow ark-sa-server patterns** - Maintain consistency with reference implementation
8. **Keep PRs small** - Each PR should be reviewable in < 30 minutes

---

## License

This project is licensed under the MIT License - permissive, allows commercial use, requires attribution.

---

## Contact & Support

- **Project Repository:** [Link TBD]
- **Issue Tracker:** GitHub Issues
- **Reference Project:** https://github.com/Johnny-Knighten/ark-sa-server

---

**Last Updated:** 2025-12-28
**Version:** 1.0.0
**Status:** Feature Parity with ark-sa-server Achieved
