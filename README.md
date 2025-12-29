# Vein Game Server - Docker Container

[![GitHub (Pre-)Release Date](https://img.shields.io/github/release-date-pre/Johnny-Knighten/vein-server?logo=github)](https://github.com/Johnny-Knighten/vein-server/releases)
[![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/Johnny-Knighten/vein-server/build-and-test.yml?logo=github&label=build%20and%20test%20-%20status)](https://github.com/Johnny-Knighten/vein-server/actions/workflows/build-and-test.yml)
[![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/Johnny-Knighten/vein-server/release.yml?logo=github&label=release%20-%20status)](https://github.com/Johnny-Knighten/vein-server/actions/workflows/release.yml)
[![GitHub Repo stars](https://img.shields.io/github/stars/Johnny-Knighten/vein-server?logo=github)](https://github.com/Johnny-Knighten/vein-server)
[![GitHub](https://img.shields.io/github/license/Johnny-Knighten/vein-server?logo=github)](https://github.com/Johnny-Knighten/vein-server/blob/main/LICENSE)

[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/johnnyknighten/vein-server?logo=docker)](https://hub.docker.com/r/johnnyknighten/vein-server)
[![Docker Stars](https://img.shields.io/docker/stars/johnnyknighten/vein-server?logo=docker)](https://hub.docker.com/r/johnnyknighten/vein-server)
[![Docker Pulls](https://img.shields.io/docker/pulls/johnnyknighten/vein-server?logo=docker)](https://hub.docker.com/r/johnnyknighten/vein-server)

Docker Linux container image for running a Vein dedicated game server.

Based on the architecture patterns from [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server).

# Table of Contents

* [Features](#features)
* [Quick Start](#quick-start)
* [Server/Game Configs](#servergame-configs)
  * [Environment Variables](#environment-variables)
  * [Exposed Ports](#exposed-ports)
  * [Volumes](#volumes)
  * [Backups](#backups)
  * [Config Files](#config-files)
* [Deployment](#deployment)
* [Tags](#tags)
* [Shout Outs](#shout-outs)
* [Contributing](#contributing)

## Features

* Simple automated installation of Vein dedicated server via SteamCMD
* Configuration via environment variables and config files
* Scheduled server restarts and updates via Cron
* Automated backups with retention policy
* Native Linux server (no Wine/Proton overhead)
* Graceful shutdown with automatic backup

## Quick Start

It is assumed you already have Docker installed on your host machine. See [here](https://docs.docker.com/engine/install/) for instructions on how to install Docker.

The commands below will run the latest version of the Vein Server in a Linux container. It will expose the default ports needed for the game server. It will also set the server name and password.

**Note - Using `docker run` by itself isn't recommended to host a server in the long term. See the [Deployment](#deployment) section for more deployment options.**

```bash
# written for bash, but should work in other shells
# may require sudo depending on your docker setup
docker run -d \
  --name vein-server \
  -p 7777:7777/udp \
  -p 27015:27015/udp \
  -e VEIN_SERVER_NAME="My Vein Server" \
  -e VEIN_SERVER_PASSWORD=secretpassword \
  -v $HOME/vein-data/server:/vein-server/server \
  -v $HOME/vein-data/logs:/vein-server/logs \
  -v $HOME/vein-data/backups:/vein-server/backups \
  johnnyknighten/vein-server:latest
```

To view the container logs:

```bash
docker logs vein-server -f
```

Press `CTRL+C` to exit the logs output.

To stop the container:

```bash
docker stop vein-server
```

## Server/Game Configs

### Environment Variables

Environment variables are the primary way to configure the server itself. For advanced game configurations, you can use config files or the `CONFIG_` environment variables.

The table below shows all the available environment variables and their default values.

| Variable | Description | Default |
| --- | --- | :---: |
| `TZ` | Sets the timezone of the container. See the table [here](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) and look in the TZ identifier column. Highly recommend to set this if you will be using any of the CRON variables. | `America/New_York` |
| `MANUAL_CONFIG` | If set to `True` then the container will not generate any config files. This is useful if you want to manage the config files yourself. | `False` |
| `SCHEDULED_RESTART` | Enable scheduled restarts of the server. | `False` |
| `BACKUP_ON_SCHEDULED_RESTART` | Determines if the server should backup itself before restarting. | `False` |
| `RESTART_CRON` | Cron expression for scheduled restarts. Default is everyday at 4am. | `0 4 * * *` |
| `SCHEDULED_UPDATE` | Enable scheduled updates of the server. | `False` |
| `UPDATE_CRON` | Cron expression for scheduled updates. Default is every Sunday at 5am. | `0 5 * * 0` |
| `BACKUP_BEFORE_UPDATE` | Determines if the server should backup itself before updating. | `True` |
| `UPDATE_ON_BOOT` | Determines if the server should update itself when it starts. If this is set to `False` then the server will only update if `SCHEDULED_UPDATE=True`, then it will update on the schedule specified by `UPDATE_CRON`. | `True` |
| `SCHEDULED_BACKUP` | Enable scheduled backups of the server. | `False` |
| `BACKUP_CRON` | Cron expression for scheduled backups. Default is every day at 6am. | `0 6 * * *` |
| `BACKUP_ON_STOP` | Determines if the server should backup itself when the container stops. | `True` |
| `ZIP_BACKUPS` | If this is set to `True` then it will zip your backups instead of the default tar and gzip. | `False` |
| `RETAIN_BACKUPS` | Number of backups to keep. If not set, then an unlimited number of backs will be kept. | EMPTY |
| `VEIN_SERVER_NAME` | Name of the server that appears in the server list. | `Vein Server` |
| `VEIN_SERVER_DESCRIPTION` | Description of the server. | `A Vein dedicated server` |
| `VEIN_SERVER_PASSWORD` | Password to login to the server. Defaults to no password aka a public server. | EMPTY |
| `VEIN_SERVER_PUBLIC` | Show server in the public server browser. | `True` |
| `VEIN_SERVER_PORT` | Primary game port. | `7777` |
| `VEIN_SERVER_QUERY_PORT` | Steam query port. | `27015` |
| `VEIN_SERVER_MAX_PLAYERS` | Maximum number of players allowed on the server. | `16` |
| `VEIN_VAC_ENABLED` | Enable Steam VAC anti-cheat (0=disabled, 1=enabled). | `0` |

**Note - If you are new to CRON, check here to get help understanding the syntax: [crontab guru](https://crontab.guru/).**

### Exposed Ports

The table below shows the default ports that are exposed by the container.

| Port | Protocol | Description |
| :---: | :---: | --- |
| 7777 | UDP | Main game port |
| 27015 | UDP | Steam query port |

Make sure you have Port Forwarding configured otherwise the server will not be accessible from the internet.

Note - Always ensure that your `-p` port mappings if using docker run and the `ports` section of your docker compose match up to the ports specified via the environment variables. If they do not match up, the server will not be accessible.

### Volumes

There are three volumes used by the container:

| Volume | Description |
| --- | --- |
| /vein-server/server | Contains server files |
| /vein-server/logs | Contains all log files generated by the container |
| /vein-server/backups | Contains all automated backups |

### Backups

Backups can be performed automatically if configured. Backups are performed by making a copy of the `/vein-server/server/Vein/Saved` directory to the `/vein-server/backups` volume. The backups are named using the following format: `vein-server-{datetime}`. They are compressed as `tar.gz` files by default (can be set to zip via `ZIP_BACKUPS=True`) and are stored in the `/vein-server/backups` volume. You can configure the number of backups to keep using `RETAIN_BACKUPS`, otherwise you will need to manually delete old backups.

Backup Automation Options:
* `BACKUP_ON_SCHEDULED_RESTART` - Backup the server before a scheduled restart
* `BACKUP_BEFORE_UPDATE` - Backup the server before an update
* `BACKUP_ON_STOP` - Backup the server when the container stops
* `SCHEDULED_BACKUP` - Backup the server on a schedule

**If you are using `BACKUP_ON_STOP=True`, it is highly recommended you adjust the timeout settings of your `docker run/stop/compose` command to allow the backup process enough time to complete its backup. Without doing this, it is likely your backup will be unfinished and corrupt.**

If desired, you can also manually trigger a backup:

```bash
docker exec vein-server supervisorctl start vein-backup
```

### Config Files

Configuration files are located in the `/vein-server/server/Vein/Saved/Config/LinuxServer` directory inside the container and the primary file is `Game.ini`.

This container has two primary ways to manage config files:
* Environment Variables - Recommended
* Manually

You should not mix and match these methods. If you wish to manage the config files manually, you must set `MANUAL_CONFIG=True` to prevent the container from generating/overwriting any config files.

#### Advanced Configuration via CONFIG_ Variables

For settings not covered by simple environment variables, use `CONFIG_` variables to directly control Game.ini:

```yaml
# Format: CONFIG_<filename>_<section>_<variable>=<value>
# Use SLASH for / and DOT for . in section names

CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_AdminSteamIDs: "76561198012345678"
CONFIG_Game_SLASH_Script_SLASH_Vein_DOT_VeinGameSession_SuperAdminSteamIDs: "76561198012345678"
```

## Deployment

See the [deployment-examples/](deployment-examples/) directory for docker-compose examples:
* [basic-docker-compose.yml](deployment-examples/docker-compose/basic-docker-compose.yml) - Minimal setup
* [advanced-docker-compose.yml](deployment-examples/docker-compose/advanced-docker-compose.yml) - All features configured

## Tags

Tags used in this project are focused on the version of the GitHub release. It is not based on the game/server version.

| Tag | Description | Examples |
| ---| --- | :---: |
| latest | Latest build from `main` branch | `latest` |
| major.minor.fix | Semantic versioned releases | `1.0.0` |

There are also pre-release tags that are built from the `next` branch. These are used for testing and are not recommended for production use.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.
