# Homeserver Config

Personal self-hosted homeserver stack built around Docker Compose, a Homepage dashboard, and a handful of maintenance scripts.

This repository is meant to document the structure of the setup, keep reusable configuration in version control, and make rebuilding or migrating the server easier later.

It intentionally excludes private data such as databases, logs, certificates, media, and other runtime state.

---

## Overview

This stack currently includes:

- **n8n** for workflow automation
- **File Browser** for web-based file management
- **Uptime Kuma** for monitoring and uptime checks
- **Watchtower** for automated container updates
- **Portainer** for Docker management
- **Homepage** as the main dashboard
- **Speedtest Tracker** for internet speed history
- **Paperless-ngx** for document management and OCR
- **Audiobookshelf** for audiobooks and podcasts
- **qBittorrent** for torrent management

---

## Repository structure

```text
.
├── cleanup.sh
├── daily-health-check_v2.sh
├── .env.example
├── .gitignore
├── README.md
└── docker
    ├── docker-compose.yml
    └── homepage
        ├── bookmarks.yaml
        ├── custom.css
        ├── custom.js
        ├── docker.yaml
        ├── kubernetes.yaml
        ├── proxmox.yaml
        ├── services.yaml
        ├── settings.yaml
        └── widgets.yaml
````

---

## File layout

### Root scripts

#### `cleanup.sh`

Maintenance script for reclaiming disk space and cleaning up Docker-related leftovers.

#### `daily-health-check_v2.sh`

Improved or newer version of the health-check script.

### Docker stack

#### `docker/docker-compose.yml`

Main Docker Compose definition for the services running on the server.

### Homepage configuration

#### `docker/homepage/services.yaml`

Defines service cards shown on the dashboard.

#### `docker/homepage/widgets.yaml`

Defines dashboard widgets such as system metrics, weather, and external service data.

#### `docker/homepage/bookmarks.yaml`

Grouped bookmarks for commonly used links.

#### `docker/homepage/docker.yaml`

Docker integration config for Homepage.

#### `docker/homepage/kubernetes.yaml`

Kubernetes integration config for Homepage.

#### `docker/homepage/proxmox.yaml`

Proxmox integration config for Homepage.

#### `docker/homepage/settings.yaml`

General dashboard settings and layout behavior.

#### `docker/homepage/custom.css`

Custom Homepage styling.

#### `docker/homepage/custom.js`

Custom Homepage JavaScript behavior.

---

## Services

### n8n

n8n is used for automation workflows, webhook handling, and service-to-service integrations.

### File Browser

Provides a browser-based interface for navigating and managing files on mounted storage.

### Uptime Kuma

Used to monitor self-hosted services and track uptime and availability.

### Watchtower

Keeps containers updated automatically and can send notifications when updates happen.

### Portainer

Web UI for managing Docker containers, images, networks, volumes, and stacks.

### Homepage

Acts as the main landing page for the server, combining service links, widgets, and infrastructure shortcuts in one place.

### Speedtest Tracker

Tracks internet speed tests over time and provides a dashboard for historical performance.

### Paperless-ngx

Document management platform used for ingesting, OCR-processing, tagging, and organizing documents.

Supporting services:

* **PostgreSQL** for the database
* **Redis** as the broker/cache service

### Audiobookshelf

Hosts audiobooks and podcasts in a self-hosted web/mobile-friendly interface.

### qBittorrent

Torrent client for managing downloads.

---

## Environment variables

Secrets and machine-specific values are kept out of version control and should live in a local `.env` file.

A template is provided:

```bash
.env.example
```

To get started:

```bash
cp .env.example .env
```

Then edit `.env` with your own values.

Typical values stored there include:

* database passwords
* application keys
* admin credentials
* API tokens
* notification tokens
* service auth values
* hostname and URL-related settings

---

## What is not included

This repository does **not** include:

* real `.env` files
* SQLite/PostgreSQL databases
* logs
* TLS certificates or private keys
* media libraries
* scanned documents
* torrent state files
* app runtime data
* caches, backups, and generated metadata
* machine-local directories such as `snap/`

Examples of excluded service data:

* Paperless document archive and media storage
* Audiobookshelf database and metadata
* qBittorrent torrent state and backups
* Speedtest Tracker database and keys
* File Browser database
* service logs and runtime files

---

## Local path notes

This setup uses bind mounts that reflect my local server layout, for example:

* `/mnt/storage`
* `/mnt/docker-data`

If you want to reuse this configuration, you will probably need to adjust those paths for your own environment.

---

## Getting started

Clone the repo, create your local environment file, review the bind mounts, and start the stack.

```bash
cp .env.example .env
docker compose -f docker/docker-compose.yml up -d
```

---

## Safe publishing notes

This repository is intended to be safe for public GitHub use, but it is still a good idea to check every commit before pushing.

Recommended checks:

```bash
git status
git diff
git ls-files
```

Make sure you are **not** committing:

* `.env`
* database files
* logs
* certificates
* app data
* exported documents
* media or torrent state

---

## Future improvements

Possible future cleanup:

* replace more hard-coded paths with variables
* add backup and restore documentation
* add first-time setup notes for each service
* document reverse proxy / HTTPS setup
* split configs into reusable templates

---

## Disclaimer

This is a personal homeserver configuration tailored to my own environment.

It is best treated as a reference or starting point rather than a production-ready template for every setup.

````