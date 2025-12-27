# Vein Game Server Docker Container - Implementation Plan

## Executive Summary

This plan outlines the incremental development of a Docker container for Vein game servers, reaching feature parity with the [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server) project. The implementation uses supervisord to orchestrate a finite state machine for server lifecycle management (install → update → run), with automated backups, scheduled operations, and comprehensive configuration management.

**Key Advantages Over Manual Setup:**
- One-command deployment via Docker Compose
- Automatic updates and backups with retention policies
- 251+ game settings configurable via environment variables
- Graceful shutdown with automatic backup protection
- Scheduled restarts, updates, and backups via cron
- Native Linux performance (no Wine/Proton overhead)

---

## Project Architecture Overview

### Finite State Machine Design

The container uses supervisord to orchestrate sequential process execution, creating an implicit state machine:

```
Container Start → Bootstrap → Updater (if needed) → Server Running
                     ↓            ↓                       ↓
                  Generate    Download via          Monitor logs
                   Configs     SteamCMD             Health checks
                     ↓            ↓                       ↓
                  Validate    Backup first         Crash recovery
                   Files      Apply update              ↓
                                                   ┌──────────────┐
                                                   ↓              ↓
                                             Scheduled Ops   Manual Ops
                                             (restart/       (shutdown/
                                              update/         backup/
                                              backup)         restart)
```

### Key Architectural Decisions

1. **Base Image:** `steamcmd/steamcmd:ubuntu-22` (includes SteamCMD, tested, familiar)
2. **Process Manager:** Supervisord (same as ark-sa-server, proven pattern)
3. **Native Linux:** Vein has native Linux server (no Wine/Proton needed - simpler than ARK)
4. **Single Save File:** Vein uses `Server.vns` (simpler backups, but critical pre-update backup needed)
5. **Configuration:** ENV vars → templates → INI files (Game.ini + Engine.ini)

### Critical Differences from ARK-SA-Server

| Aspect | ARK-SA-Server | Vein Server |
|--------|---------------|-------------|
| **Platform** | Windows via Wine/Proton | Native Linux |
| **App ID** | 2430930 | 2131400 |
| **Startup** | Wine + .exe | `./VeinServer.sh -log` |
| **Config Files** | GameUserSettings.ini, Game.ini | Game.ini, Engine.ini |
| **Config Location** | WindowsServer/ | LinuxServer/ |
| **Save Files** | Multi-file .ark saves | Single Server.vns (5-min overwrite) |
| **Config Vars** | ~100 settings | 251+ console variables |
| **Admin Access** | RCON | In-game panel (\) + API (optional) |
| **Ports** | 7777, 27015, 27020 (RCON) | 7777, 27015, 8080 (API) |

---

## Incremental Implementation Phases (Feature Parity Only)

**Note:** These 7 phases focus solely on reaching feature parity with ark-sa-server. Additional features (API integration, CI/CD, Wiki, advanced docs) are listed in "Future Enhancements" section.



### Phase 1: Minimal Viable Server (MVP)
**Goal:** Basic Vein server running in Docker with manual lifecycle management

**PR 1.1: Project Foundation & Devcontainer Setup**
- Branch: `feat/project-foundation`
- Files:
  - `.devcontainer/devcontainer.json` - Docker-in-Docker config
  - `.devcontainer/post-create.sh` - Dev tools (shellcheck, shfmt)
  - `.gitignore` - Standard ignores (logs, volumes, .env)
  - `.dockerignore` - Build context optimization
  - `README.md` - Basic project description
- Testing:
  - ✓ Devcontainer builds successfully
  - ✓ Docker-in-Docker works (`docker --version`)
  - ✓ Shellcheck available
- Commit: `feat: add devcontainer with Docker-in-Docker support`

**PR 1.2: Docker Foundation (Dockerfile + Compose)**
- Branch: `feat/docker-foundation`
- Files:
  - `Dockerfile` - Base steamcmd image, directories, dependencies
  - `docker-compose.yml` - Basic volumes, ports, minimal ENV vars
- Testing:
  - ✓ `docker build -t vein-server:dev .` succeeds
  - ✓ Image size reasonable (< 2GB)
  - ✓ Volumes defined correctly
- Commit: `feat: add Dockerfile and docker-compose configuration`

**PR 1.3: Common Utilities & Logging**
- Branch: `feat/common-utilities`
- Files:
  - `scripts/common-functions.sh` - Logging, wait functions, disk checks
- Functions:
  - `log()` - Timestamped logging
  - `wait_for_process()` - Process polling
  - `wait_for_file()` - File creation wait
  - `check_disk_space()` - Disk validation
- Testing:
  - ✓ Shellcheck passes
  - ✓ Functions can be sourced
- Commit: `feat: add common utility functions for logging and process management`

**PR 1.4: Supervisord Configuration**
- Branch: `feat/supervisord-setup`
- Files:
  - `supervisord/supervisord.conf` - Basic config (bootstrap + server processes only)
- Processes:
  - `vein-bootstrap` (priority 20, autostart=true, autorestart=false)
  - `vein-server` (priority 50, autostart=false)
- Testing:
  - ✓ Config validates (supervisord -c /path/to/conf)
- Commit: `feat: add supervisord configuration for process orchestration`

**PR 1.5: System Bootstrap (PID 1)**
- Branch: `feat/system-bootstrap`
- Files:
  - `scripts/system-bootstrap.sh` - PID 1 entrypoint, signal handlers
- Features:
  - SIGTERM/SIGINT trapping
  - Supervisord startup
  - Graceful shutdown (basic - no backup yet)
- Testing:
  - ✓ Shellcheck passes
  - ✓ Signals trapped correctly
- Commit: `feat: add system bootstrap script with signal handling`

**PR 1.6: Vein Bootstrap (Initial Setup)**
- Branch: `feat/vein-bootstrap`
- Files:
  - `scripts/vein-bootstrap.sh` - Directory creation, initial validation
- Features:
  - Create `/vein-server/{server,logs,backups}`
  - Check if server files exist
  - Route to server (updater comes in Phase 2)
- Testing:
  - ✓ Shellcheck passes
  - ✓ Directories created
- Commit: `feat: add vein bootstrap for directory setup and validation`

**PR 1.7: Vein Server Runner**
- Branch: `feat/vein-server-runner`
- Files:
  - `scripts/vein-server.sh` - Execute VeinServer.sh, log tailing
- Features:
  - Change to server directory
  - Execute `./VeinServer.sh -log`
  - Tail logs to stdout
  - Basic cleanup on exit
- Testing:
  - ✓ Shellcheck passes
  - ✓ Script runs (even if server files missing)
- Commit: `feat: add vein server runner script`

**PR 1.8: Integration & E2E Testing**
- Branch: `feat/mvp-integration`
- Files:
  - Update `Dockerfile` - Copy all scripts, set entrypoint
  - Update `docker-compose.yml` - Add basic ENV vars
- Testing:
  - ✓ `docker build` succeeds
  - ✓ `docker-compose up` runs
  - ✓ SteamCMD downloads server (manual trigger initially)
  - ✓ Server starts (if files present)
  - ✓ Graceful shutdown works
  - ✓ Data persists across restarts
- Commit: `feat: integrate all MVP components for basic server functionality`

**Phase 1 Complete:** Working Vein server in Docker (manual install/update)

---

### Phase 2: Update System & State Machine
**Goal:** Automatic updates via SteamCMD with proper state transitions

**PR 2.1: SteamCMD Updater Script**
- Branch: `feat/steamcmd-updater`
- Files:
  - `scripts/vein-updater.sh` - SteamCMD update logic
- Features:
  - Run SteamCMD with App ID 2131400
  - File validation after update
  - Start vein-server on success
  - ENV vars: `VEIN_VALIDATE_FILES`
- Testing:
  - ✓ Shellcheck passes
  - ✓ SteamCMD command correct
  - ✓ Validation logic works
- Commit: `feat: add SteamCMD updater script with file validation`

**PR 2.2: FSM Routing in Bootstrap**
- Branch: `feat/fsm-routing`
- Files:
  - `scripts/vein-bootstrap.sh` - Add state routing logic
- Features:
  - Check if update needed (ENV vars, first run detection)
  - Route to updater or server
  - ENV vars: `VEIN_AUTO_UPDATE`, `VEIN_UPDATE_ON_START`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Routing logic correct
- Commit: `feat: add finite state machine routing to bootstrap`

**PR 2.3: Supervisord Process Integration**
- Branch: `feat/updater-process`
- Files:
  - `supervisord/supervisord.conf` - Add vein-updater process
- Process Config:
  - Priority 30, autostart=false, autorestart=false
- Testing:
  - ✓ Config validates
  - ✓ Process can be started manually
- Commit: `feat: add vein-updater to supervisord configuration`

**PR 2.4: Integration & E2E Testing**
- Branch: `feat/update-system-integration`
- Files:
  - Update `docker-compose.yml` - Add update-related ENV vars
- Testing:
  - ✓ First run downloads server files
  - ✓ Second run skips update (already current)
  - ✓ `VEIN_AUTO_UPDATE=false` skips update
  - ✓ File validation detects missing files
  - ✓ State transitions logged correctly
  - ✓ Failed update prevents server start
- Commit: `feat: integrate update system with state machine`

**Phase 2 Complete:** Auto-updates with FSM state transitions

---

### Phase 3: Configuration Management (Python-Based - ark-sa-server Method) ✅ **COMPLETE**
**Goal:** Generate Game.ini and Engine.ini from environment variables using Python

**STATUS:** All PRs merged. Configuration system fully operational with dual-layer ENV vars.

**NOTE:** This phase uses ark-sa-server's Python-based `config_from_env_vars` approach instead of bash templates. This is simpler, proven, and matches the reference architecture exactly.

**PR 3.1: Add Python Config Script**
- Branch: `feat/python-config-script`
- Files:
  - `config_from_env_vars/__init__.py` - Empty Python package marker
  - `config_from_env_vars/main.py` - Python script from ark-sa-server
- Features:
  - Copy ark-sa-server's `config_from_env_vars/main.py` with minimal adaptations
  - Parse `CONFIG_<filename>_<section>_<variable>` environment variables
  - Direct ENV → INI conversion (no templates needed)
  - Automatic backup creation and comparison
  - Special character handling: `SLASH` → `/`, `DOT` → `.`
  - Default path: `/vein-server/server/Vein/Saved/Config/LinuxServer`
- Testing:
  - ✓ Python script runs without errors
  - ✓ Correct path handling for Vein
- Commit: `feat: add Python config_from_env_vars script from ark-sa-server`

**PR 3.2: Install Python Script in Dockerfile**
- Branch: `feat/install-python-config`
- Files:
  - Update `Dockerfile` - Copy and install Python script
- Changes:
  - `COPY config_from_env_vars/ /usr/local/bin/config_from_env_vars`
  - `RUN chmod +x /usr/local/bin/config_from_env_vars/main.py`
  - Python3 already installed in base image (steamcmd/steamcmd:ubuntu-22)
- Testing:
  - ✓ Docker build succeeds
  - ✓ Python script accessible at `/usr/local/bin/config_from_env_vars/main.py`
- Commit: `feat: install config_from_env_vars Python script in Docker image`

**PR 3.3: Bootstrap Integration**
- Branch: `feat/bootstrap-python-config`
- Files:
  - Update `bin/vein-bootstrap.sh` - Call Python script in `generate_config_files()`
- Changes:
  - Export basic `CONFIG_*` environment variables
  - Call: `python3 /usr/local/bin/config_from_env_vars/main.py --path "${SERVER_DIR}/Vein/Saved/Config/LinuxServer"`
  - Variables: `SERVER_NAME`, `SERVER_PASSWORD`, `ADMIN_PASSWORD`, `MAX_PLAYERS`
  - Respect `MANUAL_CONFIG=True` to skip generation
- Testing:
  - ✓ Bootstrap generates Game.ini and Engine.ini
  - ✓ ENV vars correctly populate INI sections
  - ✓ MANUAL_CONFIG=True skips generation
  - ✓ Files created in correct directory
- Commit: `feat: integrate Python config generation into bootstrap`

**PR 3.4: docker-compose ENV Variable Examples**
- Branch: `feat/config-env-examples`
- Files:
  - Update `docker-compose.yml` - Add Phase 3 configuration variables
- Changes:
  - Document `CONFIG_*` variable format
  - Add basic server variables: `SERVER_NAME`, `SERVER_PASSWORD`, `ADMIN_PASSWORD`, `MAX_PLAYERS`
  - Add commented examples: `CONFIG_Game_ServerSettings_PvPEnabled`, etc.
  - Explain special character replacement (`SLASH`, `DOT`)
- Testing:
  - ✓ docker-compose.yml validates
  - ✓ ENV vars documented clearly
  - ✓ Examples work when uncommented
- Commit: `feat: add Phase 3 CONFIG_ variable examples to docker-compose`

**PR 3.5: Integration Testing & Documentation**
- Branch: `feat/config-integration-test`
- Tasks:
  1. Build Docker image with all Phase 3 changes
  2. Test with various `CONFIG_*` environment variables
  3. Verify generated Game.ini and Engine.ini files
  4. Test MANUAL_CONFIG=True mode
  5. Update CLAUDE.md with `CONFIG_*` variable documentation
- Testing:
  - ✓ First run generates configs from ENV vars
  - ✓ `CONFIG_Game_*` variables populate Game.ini correctly
  - ✓ `CONFIG_Engine_*` variables populate Engine.ini correctly
  - ✓ SLASH and DOT replacements work (`CONFIG_Game_SLASH_Script_SLASH_Engine_DOT_GameSession_MaxPlayers`)
  - ✓ Backup files created when configs change
  - ✓ MANUAL_CONFIG=True skips generation
  - ✓ Server starts with generated configs
- Commit: `feat: complete Phase 3 config integration with testing`

**Phase 3 Complete:** Python-based ENV-driven configuration (ark-sa-server method)

**Key Changes from Original Plan:**
- ❌ **REMOVED:** Game.ini.template, Engine.ini.template, preset .env files, bash vein-config-generator.sh
- ✅ **ADDED:** Python config_from_env_vars script (direct copy from ark-sa-server)
- ✅ **BENEFIT:** Simpler, proven code, matches reference architecture exactly

---

### Phase 4: Backup System
**Goal:** Automated backups with multiple triggers, compression, and retention (ark-sa-server parity)

**NOTE:** ENV variables match ark-sa-server exactly - NO `VEIN_` prefix (system-level settings)

**PR 4.1: Core Backup Script**
- Branch: `feat/backup-core`
- Files:
  - `bin/vein-backup.sh` - Main backup logic
- Features:
  - Backup `Vein/Saved` directory
  - Timestamped naming: `vein-backup-YYYY-MM-DD-HH-MM-SS.{tar.gz|zip}`
  - Boolean `ZIP_BACKUPS` handling (True=ZIP, False=tar.gz)
  - Empty `RETAIN_BACKUPS` = unlimited backups
  - Basic timeout (600s)
  - ENV vars: `ZIP_BACKUPS`, `RETAIN_BACKUPS`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Creates tar.gz when `ZIP_BACKUPS=False`
  - ✓ Creates ZIP when `ZIP_BACKUPS=True`
  - ✓ Unlimited backups when `RETAIN_BACKUPS=""`
  - ✓ Timeout works
- Commit: `feat: add core backup script with compression`

**PR 4.2: Retention Policy**
- Branch: `feat/backup-retention`
- Files:
  - Update `bin/vein-backup.sh`
  - Update `bin/common-functions.sh` - Add retention helpers
- Features:
  - `cleanup_old_backups()` function
  - Handle empty `RETAIN_BACKUPS` (unlimited)
  - Sort by timestamp, delete oldest first
  - ENV var: `RETAIN_BACKUPS` (default: empty = unlimited)
- Testing:
  - ✓ Empty value keeps all backups
  - ✓ `RETAIN_BACKUPS=10` deletes 11th oldest
  - ✓ Works with both tar.gz and ZIP
- Commit: `feat: add backup retention policy management`

**PR 4.3: Backup Verification & Error Handling**
- Branch: `feat/backup-verification`
- Files:
  - Update `bin/vein-backup.sh`
- Features:
  - Test archive integrity after creation
  - Disk space check before backup
  - Better error messages and logging
- Testing:
  - ✓ tar.gz verified correctly
  - ✓ ZIP verified correctly
  - ✓ Corrupted archives detected
  - ✓ Fails gracefully on low disk space
- Commit: `feat: add backup verification and error handling`

**PR 4.4: On-Stop Backup Trigger**
- Branch: `feat/backup-on-stop`
- Files:
  - Update `bin/system-bootstrap.sh` - Add backup to cleanup()
  - Update `supervisord/supervisord.conf` - Add vein-backup-on-stop process
- Features:
  - Check `BACKUP_ON_STOP` in cleanup() function
  - Trigger supervisord process `vein-backup-on-stop`
  - Wait for completion (600s max)
  - ENV var: `BACKUP_ON_STOP` (default: True)
- Testing:
  - ✓ Backup created on `docker stop`
  - ✓ Container waits for backup completion
  - ✓ `BACKUP_ON_STOP=False` skips backup
  - ✓ Timeout prevents hang
- Commit: `feat: add on-stop backup trigger for graceful shutdown`

**PR 4.5: Pre-Update Backup Trigger**
- Branch: `feat/backup-pre-update`
- Files:
  - Update `bin/vein-updater.sh` - Trigger backup before SteamCMD
  - Update `supervisord/supervisord.conf` - Add vein-backup-pre-update process
- Features:
  - Check `BACKUP_BEFORE_UPDATE` before SteamCMD runs
  - Trigger supervisord process `vein-backup-pre-update`
  - Critical for Server.vns safety (5-min overwrite)
  - ENV var: `BACKUP_BEFORE_UPDATE` (default: True for Vein, False for ARK)
- Testing:
  - ✓ Pre-update backup created
  - ✓ Update waits for backup completion
  - ✓ `BACKUP_BEFORE_UPDATE=False` skips backup
  - ✓ Server.vns safely backed up
- Commit: `feat: add pre-update backup trigger for data safety`

**PR 4.6: Scheduled Restart Backup Trigger (NEW - Missing Feature)**
- Branch: `feat/backup-on-restart`
- Files:
  - Update `bin/vein-scheduled-restart.sh` - Add backup trigger
  - Update `supervisord/supervisord.conf` - Add vein-backup-on-scheduled-restart process
- Features:
  - Check `BACKUP_ON_SCHEDULED_RESTART` in restart handler
  - Trigger backup before server stop (separate from standalone backups)
  - ENV var: `BACKUP_ON_SCHEDULED_RESTART` (default: False)
- Testing:
  - ✓ Backup created before scheduled restart
  - ✓ `BACKUP_ON_SCHEDULED_RESTART=False` skips backup
  - ✓ Works independently of `SCHEDULED_BACKUP`
- Commit: `feat: add scheduled restart backup trigger`

**PR 4.7: Standalone Scheduled Backup Setup**
- Branch: `feat/scheduled-backup-setup`
- Files:
  - Update `bin/vein-scheduled-backup.sh` - Standalone backup handler
  - Update `bin/cron-setup.sh` - Add SCHEDULED_BACKUP logic
- Features:
  - Check `SCHEDULED_BACKUP` flag to enable cron job
  - Use `BACKUP_CRON` schedule for standalone backups
  - Independent of restart/update backups
  - ENV vars: `SCHEDULED_BACKUP` (default: False), `BACKUP_CRON` (default: "0 6 * * *")
- Testing:
  - ✓ Cron job created when `SCHEDULED_BACKUP=True`
  - ✓ No cron job when `SCHEDULED_BACKUP=False`
  - ✓ `BACKUP_CRON` schedule respected
  - ✓ Backup runs without stopping server
- Commit: `feat: add standalone scheduled backup configuration`

**PR 4.8: Integration & E2E Testing**
- Branch: `feat/backup-integration`
- Files:
  - Update `docker-compose.yml` - Add Phase 4 backup ENV vars
- Testing:
  - ✓ All four backup triggers work independently:
    1. `BACKUP_ON_STOP=True` → shutdown backup
    2. `BACKUP_BEFORE_UPDATE=True` → pre-update backup
    3. `BACKUP_ON_SCHEDULED_RESTART=True` → pre-restart backup
    4. `SCHEDULED_BACKUP=True` + `BACKUP_CRON` → standalone cron backup
  - ✓ Retention policy enforced across all triggers
  - ✓ ZIP and tar.gz formats work correctly
  - ✓ Unlimited retention works (empty `RETAIN_BACKUPS`)
  - ✓ Backup archives verified successfully
  - ✓ Backup restores successfully
- Commit: `feat: integrate backup system with all triggers`

**Phase 4 Complete:** Multi-trigger backup with retention (8 PRs, ark-sa-server parity)

**Key Differences from ARK:**
- `BACKUP_BEFORE_UPDATE` defaults to `True` (Vein-specific safety due to Server.vns 5-min overwrite)
- All other defaults match ARK exactly

---

### Phase 5: Scheduled Operations
**Goal:** Cron-based scheduled restarts, updates, and backups

**PR 5.1: Cron Setup Script**
- Branch: `feat/cron-setup`
- Files:
  - `scripts/cron-setup.sh` - Generate crontab from ENV vars
  - `cron/vein-cron.template` - Crontab template
- Features:
  - Parse cron ENV vars
  - Generate crontab file
  - Output to `/vein-server/logs/cron.log`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Valid crontab generated
- Commit: `feat: add cron setup script and template`

**PR 5.2: Scheduled Backup Handler**
- Branch: `feat/scheduled-backup`
- Files:
  - `scripts/vein-scheduled-backup.sh` - Backup without restart
  - Update `scripts/common-functions.sh` - Add lock file helpers
- Features:
  - Lock file prevents concurrent ops
  - Trigger existing backup script
  - ENV var: `VEIN_BACKUP_CRON`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Lock file works
  - ✓ Backup runs without stopping server
- Commit: `feat: add scheduled backup handler with lock file protection`

**PR 5.3: Scheduled Restart Handler**
- Branch: `feat/scheduled-restart`
- Files:
  - `scripts/vein-scheduled-restart.sh` - Graceful restart
- Features:
  - Stop server via supervisorctl
  - Trigger backup
  - Restart server
  - Log-based warnings (no RCON)
  - ENV var: `VEIN_RESTART_ENABLED`, `VEIN_RESTART_CRON`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Graceful restart works
  - ✓ No data loss
- Commit: `feat: add scheduled restart handler with backup`

**PR 5.4: Scheduled Update Handler**
- Branch: `feat/scheduled-update`
- Files:
  - `scripts/vein-scheduled-update.sh` - Update handler
- Features:
  - Stop server
  - Trigger pre-update backup
  - Run updater
  - Server restarts after update
  - ENV var: `VEIN_UPDATE_CRON`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Update triggers backup first
  - ✓ Server restarts correctly
- Commit: `feat: add scheduled update handler`

**PR 5.5: Supervisord Crond Integration**
- Branch: `feat/crond-process`
- Files:
  - Update `supervisord/supervisord.conf` - Add crond process
  - Update `scripts/system-bootstrap.sh` - Call cron-setup.sh
- Process Config:
  - Priority 10, autostart=true, autorestart=true
  - Run as root
- Testing:
  - ✓ Crond starts automatically
  - ✓ Cron jobs registered
- Commit: `feat: add crond to supervisord configuration`

**PR 5.6: Integration & E2E Testing**
- Branch: `feat/scheduling-integration`
- Files:
  - Update `docker-compose.yml` - Add scheduling ENV examples
- Testing:
  - ✓ Cron jobs execute on schedule (test `* * * * *`)
  - ✓ Scheduled restart graceful
  - ✓ Scheduled update works
  - ✓ Scheduled backup works
  - ✓ Lock file prevents conflicts
  - ✓ Cron logs accessible
- Commit: `feat: integrate scheduled operations with cron`

**Phase 5 Complete:** Cron-based automated operations

---

### Phase 6: Health Monitoring & Recovery
**Goal:** Health checks, startup detection, crash recovery

**PR 6.1: Startup Detection in Server Runner**
- Branch: `feat/startup-detection`
- Files:
  - Update `scripts/vein-server.sh`
- Features:
  - Parse logs for startup success
  - 300s startup timeout
  - Monitor VeinServer.sh process
  - Better error reporting
- Testing:
  - ✓ Shellcheck passes
  - ✓ Startup detected correctly
  - ✓ Timeout works
- Commit: `feat: add startup detection and timeout to server runner`

**PR 6.2: Docker Healthcheck Script**
- Branch: `feat/healthcheck-script`
- Files:
  - `scripts/vein-healthcheck.sh` - Docker HEALTHCHECK
- Checks:
  - VeinServer.sh process running
  - Query port 27015/UDP responds
  - Log file updated recently (< 5 min)
  - ENV var: `VEIN_HEALTH_CHECK_ENABLED`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Returns 0 when healthy
  - ✓ Returns 1 when unhealthy
- Commit: `feat: add Docker healthcheck script`

**PR 6.3: Dockerfile Healthcheck Directive**
- Branch: `feat/docker-healthcheck`
- Files:
  - Update `Dockerfile` - Add HEALTHCHECK
- Directive:
  - Interval: 60s
  - Timeout: 10s
  - Retries: 3
  - Start period: 300s
- Testing:
  - ✓ Image builds
  - ✓ `docker ps` shows health status
- Commit: `feat: add HEALTHCHECK directive to Dockerfile`

**PR 6.4: Process Monitor Script**
- Branch: `feat/process-monitor`
- Files:
  - `scripts/vein-monitor.sh` - Crash detection and recovery
  - Update `scripts/common-functions.sh` - Add backoff helpers
- Features:
  - Monitor vein-server process
  - Detect crashes
  - Exponential backoff restart
  - Prevent crash loops (max 3 retries)
  - ENV vars: `VEIN_RESTART_ON_CRASH`, `VEIN_CRASH_RESTART_DELAY`
- Testing:
  - ✓ Shellcheck passes
  - ✓ Crash detection works
  - ✓ Backoff prevents loops
- Commit: `feat: add process monitor with crash recovery`

**PR 6.5: Error Pattern Detection**
- Branch: `feat/error-patterns`
- Files:
  - Update `scripts/vein-monitor.sh`
- Patterns:
  - OOM errors
  - Segmentation faults
  - Steam auth failures
  - Disk full errors
- Testing:
  - ✓ Patterns detected in logs
  - ✓ Appropriate actions taken
- Commit: `feat: add error pattern detection to monitor`

**PR 6.6: Supervisord Monitor Integration**
- Branch: `feat/monitor-integration`
- Files:
  - Update `supervisord/supervisord.conf` - Add vein-monitor process
- Process Config:
  - Priority 60, autostart=true, autorestart=true
- Testing:
  - ✓ Monitor starts automatically
  - ✓ Monitors vein-server process
- Commit: `feat: integrate process monitor with supervisord`

**PR 6.7: Integration & E2E Testing**
- Branch: `feat/monitoring-integration`
- Files:
  - Update `docker-compose.yml` - Add monitoring ENV examples
- Testing:
  - ✓ `docker ps` shows "healthy"
  - ✓ Health check fails when server down
  - ✓ `kill -9` triggers restart
  - ✓ Backoff prevents crash loops
  - ✓ Startup timeout works
  - ✓ Error patterns detected
- Commit: `feat: integrate health monitoring and crash recovery`

**Phase 6 Complete:** Full health monitoring with auto-recovery

---

### Phase 7: Documentation & Release Prep
**Goal:** Comprehensive documentation matching ark-sa-server quality

**PR 7.1: MIT License**
- Branch: `docs/add-license`
- Files:
  - `LICENSE` - MIT License file
- Testing:
  - ✓ License valid and complete
- Commit: `docs: add MIT License`

**PR 7.2: Example Docker Compose Files**
- Branch: `docs/docker-compose-examples`
- Files:
  - `examples/docker-compose.basic.yml` - Minimal setup
  - `examples/docker-compose.advanced.yml` - All features
- Examples:
  - Basic: Core server settings only
  - Advanced: All features (backups, scheduling, monitoring)
- Testing:
  - ✓ Both examples start successfully
  - ✓ YAML valid
- Commit: `docs: add docker-compose examples (basic and advanced)`

**PR 7.3: CLAUDE.md**
- Branch: `docs/claude-md`
- Files:
  - `CLAUDE.md` - AI assistant context
- Contents:
  - Project overview and architecture
  - Development setup (devcontainer)
  - State machine diagrams
  - Directory structure
  - Script responsibilities
  - ENV variable reference
  - Git workflow (branching, PRs)
  - Testing procedures
  - Feature parity checklist
- Testing:
  - ✓ All sections complete
  - ✓ Code examples valid
- Commit: `docs: add comprehensive CLAUDE.md for AI assistance`

**PR 7.4: Comprehensive README (Part 1)**
- Branch: `docs/readme-part1`
- Files:
  - Update `README.md` - Overview, Quick Start, Installation
- Sections:
  - Project overview and features
  - Quick Start (3-step deploy)
  - Detailed installation
  - System requirements
- Testing:
  - ✓ Quick start works in < 5 minutes
  - ✓ All links valid
- Commit: `docs: add README overview, quick start, and installation`

**PR 7.5: Comprehensive README (Part 2)**
- Branch: `docs/readme-part2`
- Files:
  - Update `README.md` - Configuration, Usage, Volumes
- Sections:
  - Configuration (ENV var table)
  - Usage (common operations)
  - Volumes and data persistence
  - Ports and networking
- Testing:
  - ✓ ENV var table complete
  - ✓ Examples work copy-paste
- Commit: `docs: add README configuration and usage sections`

**PR 7.6: Comprehensive README (Part 3)**
- Branch: `docs/readme-part3`
- Files:
  - Update `README.md` - Backup, Scheduling, Troubleshooting
- Sections:
  - Backup and restore
  - Scheduled operations
  - Troubleshooting
  - Contributing
  - License
- Testing:
  - ✓ Troubleshooting covers common issues
  - ✓ Documentation complete
- Commit: `docs: add README backup, scheduling, and troubleshooting`

**PR 7.7: Release Preparation**
- Branch: `chore/release-prep`
- Files:
  - `.releaserc` - semantic-release config
  - Update `docker-compose.yml` - Use latest tag
  - Update `README.md` - Add badges, Docker Hub links
- Features:
  - semantic-release configuration
  - Versioning strategy documented
  - Release notes template
- Testing:
  - ✓ semantic-release config valid
  - ✓ All docs reference correct tags
- Commit: `chore: prepare project for v1.0.0 release`

**Phase 7 Complete:** Production-ready documentation

---

## Directory Structure (Final State)

```
vein-server/
├── Dockerfile                              # Container image definition
├── docker-compose.yml                      # Primary deployment method
├── .dockerignore                          # Build context optimization
├── .gitignore                             # Git ignore patterns
├── README.md                              # Project documentation
├── CLAUDE.md                              # AI assistant context
├── LICENSE                                # Project license (TBD)
│
├── .devcontainer/
│   ├── devcontainer.json                  # Docker-in-Docker config
│   └── post-create.sh                     # Dev tools setup
│
├── .github/
│   └── (empty - CI/CD is future enhancement)
│
├── scripts/                               # Runtime scripts (copied to container)
│   ├── system-bootstrap.sh                # PID 1 entrypoint, signal handling
│   ├── vein-bootstrap.sh                  # State router, config generator
│   ├── vein-updater.sh                    # SteamCMD update manager
│   ├── vein-server.sh                     # Server runner, log monitor
│   ├── vein-backup.sh                     # Backup manager (all variants)
│   ├── vein-config-generator.sh           # ENV → INI converter
│   ├── vein-healthcheck.sh                # Docker healthcheck
│   ├── vein-monitor.sh                    # Process monitoring
│   ├── vein-scheduled-restart.sh          # Scheduled restart handler
│   ├── vein-scheduled-update.sh           # Scheduled update handler
│   ├── vein-scheduled-backup.sh           # Scheduled backup handler
│   ├── cron-setup.sh                      # Cron initialization
│   └── common-functions.sh                # Shared utilities
│
├── supervisord/
│   └── supervisord.conf                   # Process orchestration config
│
├── cron/
│   └── vein-cron                          # Crontab file template
│
├── templates/
│   ├── Game.ini.template                  # Game config template
│   ├── Engine.ini.template                # Engine config template
│   └── presets/
│       ├── default.env                    # Default values
│       ├── pve-friendly.env               # PvE preset
│       └── pvp-hardcore.env               # PvP preset
│
├── docs/
│   └── (future - for now all docs in README matching ark-sa-server)
│
└── examples/
    ├── docker-compose.basic.yml           # Basic setup
    └── docker-compose.advanced.yml        # All features enabled
```

**Runtime Directory Structure (Inside Container):**
```
/vein-server/
├── server/                                # VOLUME - Game server files
│   ├── VeinServer.sh
│   ├── Vein/
│   │   ├── Binaries/Linux/
│   │   ├── Content/
│   │   └── Saved/
│   │       ├── Config/LinuxServer/
│   │       │   ├── Game.ini
│   │       │   └── Engine.ini
│   │       └── SaveGames/
│   │           └── Server.vns
│   └── steamapps/
├── logs/                                  # VOLUME - Log files
│   ├── bootstrap.log
│   ├── updater.log
│   ├── server.log
│   ├── backup.log
│   ├── cron.log
│   └── supervisord.log
├── backups/                               # VOLUME - Backup archives
│   └── vein-backup-2025-01-15-04-00-00.tar.gz
├── scripts/                               # Runtime scripts
├── templates/                             # Config templates
├── supervisord/                           # Supervisord config
└── cron/                                  # Cron config
```

---

## Environment Variables Reference (Summary)

**Core Server:**
- `VEIN_SERVER_NAME` - Server name (default: "Vein Server")
- `VEIN_SERVER_PASSWORD` - Server password (default: empty)
- `VEIN_SERVER_ADMIN_PASSWORD` - Admin password (default: "admin")
- `VEIN_SERVER_MAX_PLAYERS` - Max players (default: 32)
- `VEIN_SERVER_PORT` - Game port (default: 7777)
- `VEIN_SERVER_QUERY_PORT` - Query port (default: 27015)

**Updates:**
- `VEIN_AUTO_UPDATE` - Auto-update on start (default: true)
- `VEIN_VALIDATE_FILES` - Validate after update (default: true)
- `VEIN_UPDATE_ON_START` - Update before first run (default: true)

**Backups (ark-sa-server parity - NO VEIN_ prefix):**
- `BACKUP_ON_STOP` - Backup on shutdown (default: True)
- `BACKUP_ON_SCHEDULED_RESTART` - Backup before scheduled restarts (default: False)
- `BACKUP_BEFORE_UPDATE` - Backup before updates (default: True for Vein, False for ARK)
- `SCHEDULED_BACKUP` - Enable standalone backup cron (default: False)
- `BACKUP_CRON` - Standalone backup schedule (default: "0 6 * * *")
- `ZIP_BACKUPS` - Use ZIP format (default: False = tar.gz)
- `RETAIN_BACKUPS` - Keep N backups (default: empty = unlimited)

**Scheduling:**
- `VEIN_RESTART_ENABLED` - Enable scheduled restarts (default: false)
- `VEIN_RESTART_CRON` - Restart schedule (default: "0 4 * * *")
- `VEIN_UPDATE_CRON` - Update schedule (default: "0 3 * * *")
- `VEIN_BACKUP_CRON` - Backup schedule (default: "0 */6 * * *")

**Gameplay (Examples - 251+ total):**
- `VEIN_PVP_ENABLED` - Enable PvP (default: false)
- `VEIN_PVP_DAMAGE_MULTIPLIER` - PvP damage (default: 1.0)
- `VEIN_ZOMBIE_SPAWN_RATE` - Zombie spawns (default: 1.0)
- `VEIN_ZOMBIE_DIFFICULTY` - Zombie difficulty (default: 1.0)
- `VEIN_TIME_DAY_MULTIPLIER` - Day length (default: 1.0)
- `VEIN_TIME_NIGHT_MULTIPLIER` - Night length (default: 1.0)

Full reference: [docs/CONFIGURATION.md](../../../docs/CONFIGURATION.md)

---

## Testing Strategy

### Phase 1 Testing (MVP):
```bash
# Build image
docker build -t vein-server:dev .

# Run with docker-compose
docker-compose up

# Verify server starts
docker logs -f vein-server

# Verify ports
nc -vz localhost 7777  # Game port
nc -vz localhost 27015 # Query port

# Graceful shutdown
docker-compose down

# Verify data persists
docker-compose up
```

### Integration Testing (All Phases):
```bash
# Test update system
docker-compose up
docker exec vein-server supervisorctl start vein-updater

# Test backup system
docker exec vein-server supervisorctl start vein-backup-scheduled

# Test configuration
docker-compose down
# Edit docker-compose.yml ENV vars
docker-compose up
# Verify configs in Vein/Saved/Config/LinuxServer/

# Test scheduled operations
docker exec vein-server crontab -l
docker exec vein-server tail -f /vein-server/logs/cron.log

# Test health check
docker inspect vein-server | jq '.[0].State.Health'

# Test crash recovery
docker exec vein-server pkill -9 VeinServer
# Watch auto-restart
docker logs -f vein-server
```

---

## Success Metrics (Feature Parity Checklist)

### ✅ Core Features (ARK-SA-Server Parity):
- [ ] Supervisord process orchestration
- [ ] Finite state machine (bootstrap → updater → server)
- [ ] SteamCMD integration for updates
- [ ] Automatic updates on start
- [ ] File validation after update
- [ ] Graceful shutdown with cleanup
- [ ] Signal handling (SIGTERM, SIGINT)

### ✅ Configuration:
- [ ] ENV var → INI file generation
- [ ] Template-based configuration
- [ ] Default value handling
- [ ] Configuration presets
- [ ] Validation for required settings

### ✅ Backup System (ark-sa-server parity):
- [ ] On-stop backups (`BACKUP_ON_STOP`)
- [ ] Pre-update backups (`BACKUP_BEFORE_UPDATE`)
- [ ] Scheduled restart backups (`BACKUP_ON_SCHEDULED_RESTART`)
- [ ] Standalone scheduled backups (`SCHEDULED_BACKUP` + `BACKUP_CRON`)
- [ ] Retention policy management (`RETAIN_BACKUPS` with unlimited default)
- [ ] tar.gz and ZIP compression (`ZIP_BACKUPS` boolean)
- [ ] Backup verification
- [ ] 600s timeout protection

### ✅ Scheduled Operations:
- [ ] Cron-based scheduling
- [ ] Scheduled restarts
- [ ] Scheduled updates
- [ ] Scheduled backups
- [ ] Pre-restart warnings (log-based)

### ✅ Monitoring:
- [ ] Health checks
- [ ] Startup detection
- [ ] Crash recovery
- [ ] Error pattern detection
- [ ] Log aggregation

### ✅ Documentation:
- [ ] Comprehensive README
- [ ] ENV var reference
- [ ] Troubleshooting guide
- [ ] Example configurations
- [ ] CLAUDE.md for AI assistance

### 🎯 Vein-Specific Enhancements:
- [ ] 251+ console variable support
- [ ] Native Linux execution (simpler than ARK)
- [ ] Single save file backup (Server.vns)
- [ ] Configuration categories (PvP, zombies, time, loot, etc.)
- [ ] Optional API integration (Phase 7)

---

## Next Steps

1. **Review this plan** - Ensure alignment with your vision
2. **Clarify any questions** - Discuss ambiguous points
3. **Proceed with Phase 1** - Start with MVP implementation
4. **Iterate incrementally** - Each phase builds on previous
5. **Test thoroughly** - Each phase has clear test criteria
6. **Document as you go** - Update docs with each phase

---

## Project Decisions (Confirmed)

1. **License:** MIT License (permissive, allows commercial use)
2. **Image Registry:** Docker Hub (primary)
3. **Versioning:** Semantic versioning (vX.Y.Z) via semantic-release
4. **Scope:** Focus on feature parity with ark-sa-server (7 phases)
5. **Future Enhancements:** API, CI/CD, advanced docs deferred post-parity
6. **Documentation:** All in README initially (matching ark-sa-server approach)
7. **Branching Strategy:** Two long-running branches (main, next)
8. **Release Process:** semantic-release (prepare in next, merge to main for release)
9. **PR Strategy:** Each unit of work = 1 PR, grouped by feature/fix

---

## Summary

This plan provides a comprehensive roadmap for creating a production-ready Vein game server Docker container with full feature parity to ark-sa-server, adapted for Vein's native Linux execution and unique configuration system. The phased approach allows for incremental development, testing, and user feedback, with each phase delivering tangible value.

**Estimated Timeline:** 3-4 weeks for feature parity (Phases 1-7)
**Total PRs:** ~45 PRs across 7 phases (Phase 4 has 8 PRs for ark-sa-server parity)
**Phase 1 Timeline:** 1 week (8 PRs - MVP with working server)
**Phase 4 Timeline:** Updated to 8 PRs (added `BACKUP_ON_SCHEDULED_RESTART` feature)

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

- **`feat/*`** - New features (e.g., `feat/backup-core`)
- **`fix/*`** - Bug fixes (e.g., `fix/healthcheck-timeout`)
- **`docs/*`** - Documentation only (e.g., `docs/readme-part1`)
- **`chore/*`** - Maintenance tasks (e.g., `chore/release-prep`)

## Git Workflow

### For Each PR (Feature/Fix):

1. **Checkout and Rebase:**
   ```bash
   git checkout main
   git pull origin main
   git checkout next
   git pull origin next
   git rebase main
   ```

2. **Create Feature Branch:**
   ```bash
   # From next branch
   git checkout -b feat/feature-name
   # or
   git checkout -b fix/bug-name
   ```

3. **Develop and Commit:**
   ```bash
   # Make changes
   git add .
   git commit -m "feat: add feature description"
   # Follow conventional commits:
   # - feat: new feature
   # - fix: bug fix
   # - docs: documentation
   # - chore: maintenance
   ```

4. **Lint and Test Locally:**
   ```bash
   # Run shellcheck on scripts
   shellcheck scripts/*.sh

   # Build and test
   docker build -t vein-server:dev .
   docker-compose up

   # Fix any issues before pushing
   ```

5. **Push and Open PR:**
   ```bash
   git push origin feat/feature-name

   # Open PR on GitHub targeting 'next' branch
   # Title: feat: add feature description
   # Description: Details of changes, testing done
   ```

6. **Merge and Cleanup:**
   ```bash
   # After PR approved and merged to next:
   git checkout next
   git pull origin next
   git branch -d feat/feature-name
   ```

### Release Workflow:

1. **Prepare Release in `next`:**
   ```bash
   # All features for release merged to next
   # Run semantic-release in next branch
   # Generates changelog, bumps version
   ```

2. **Merge to `main`:**
   ```bash
   # Create release PR: next → main
   git checkout main
   git pull origin main
   git merge next
   git push origin main

   # semantic-release creates git tag
   # Docker Hub builds from tag
   ```

3. **Post-Release:**
   ```bash
   # Sync next with main
   git checkout next
   git merge main
   git push origin next
   ```

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add backup retention policy` - New feature
- `fix: correct healthcheck timeout logic` - Bug fix
- `docs: update README configuration section` - Documentation
- `chore: update dependencies` - Maintenance
- `refactor: simplify config generator` - Code refactoring
- `test: add backup verification tests` - Tests
- `perf: optimize log parsing` - Performance

**Breaking Changes:**
```
feat!: change ENV var naming convention

BREAKING CHANGE: All ENV vars now use VEIN_ prefix instead of GAME_
```

---

## Future Enhancements (Post Feature Parity)

Once feature parity with ark-sa-server is achieved, these enhancements can be added:

### 1. API Integration
- Vein API support (port 8080/TCP)
- In-game broadcast messages for pre-restart warnings
- Player list and server status queries
- Admin command execution via API
- Requires research into Vein's undocumented API

### 2. CI/CD Pipeline
- GitHub Actions for automated Docker Hub builds
- Shellcheck linting on PRs
- Automated tagging and versioning
- Multi-architecture builds (amd64, arm64)

### 3. Enhanced Documentation
- Separate docs/ directory with detailed guides
- Configuration reference (all 251+ variables)
- Troubleshooting guide with common issues
- Migration guide from manual setup
- Performance tuning guide
- GitHub Wiki pages

### 4. Community Features
- GitHub issue and PR templates
- Contributing guidelines
- Code of conduct
- Additional configuration presets (roleplay, hardcore, etc.)

### 5. Advanced Monitoring
- Prometheus metrics export
- Grafana dashboard templates
- Discord webhook notifications
- Player activity tracking

### 6. Cluster Support
- Multi-server clustering
- Shared save data between servers
- Load balancing considerations

These features go beyond ark-sa-server's current capabilities and should only be implemented after achieving parity and gathering community feedback.
