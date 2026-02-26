# Smokeping Docker Stack
### With Smart Telegram Alerts · Revamped

[![Docs](https://img.shields.io/badge/Styled_Docs-View_Page-00e5ff?style=for-the-badge&logo=github)](https://xeesan.github.io/smokeping-docker)
[![License](https://img.shields.io/badge/License-MIT-7c3aed?style=for-the-badge)]()
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)](https://docs.docker.com/compose/)

> A fully containerized Smokeping environment tailored for reliable network monitoring. Bundles the core Smokeping daemon, Apache2 web UI, a custom geolocation-aware Telegram alerting system, and sidecar containers for secure remote management via Cloudflare and Tailscale.
>
> ⚡ Optimized for tracking latency on specific targets (e.g., Game Servers, CDNs).

---

## Features

**📡 Standard Polling**
Configured for default 300-second steps and 20 pings per step to establish a reliable baseline.

**🤖 Smart Telegram Alerts**
Custom automated script parses RTT/loss data and routes detailed alerts (power down, host down, latency spikes) with emoji headers and ipinfo.io geolocation tags.

**🔒 Zero-Trust Access**
- `cloudflared` tunnel exposes the web UI without opening inbound ports.
- `tailscale` handles private SSH/backend access to the container network.

**💾 Persistent Storage**
RRD database files are mounted to a local Docker volume so historical graphs survive container rebuilds.

---

## Prerequisites

Before spinning this up, you will need:

- [ ] Telegram Bot Token & Chat ID
- [ ] Cloudflare Tunnel Token
- [ ] Tailscale Auth Key

---

## Directory Tree

```
smokeping-docker/
│
├── index.html                       ← GitHub Pages styled docs
├── Dockerfile
├── start.sh
├── smokeping-telegram-alert.sh
├── docker-compose.yml
│
└── config/
    ├── Targets      ← Add your custom ping targets here
    ├── Alerts       ← Alert thresholds and check alert name if needed
    └── Database     ← Limits (step=300, pings=20)
```

---

## Installation & Setup

**1. Clone the Repository**

```bash
git clone https://github.com/Xeesan/smokeping-docker.git
cd smokeping-docker
```

**2. Configure Telegram Alerts**

Open `smokeping-telegram-alert.sh` and input your credentials:

```bash
BOT_TOKEN="your_telegram_bot_token"
CHAT_ID="your_telegram_chat_id"
```

**3. Add Zero-Trust Credentials**

Open `docker-compose.yml` and paste your access keys:

```yaml
TUNNEL_TOKEN=your_cloudflare_tunnel_token_here
TS_AUTHKEY=your_tailscale_auth_key_here
```

**4. Define Your Targets**

Open `config/Targets` and add your IPs, game servers, or web hosts following the Smokeping syntax.

**5. Deploy the Stack**

```bash
docker-compose up -d --build
```

---

## Troubleshooting

**⚠️ Permissions Issue**

If Smokeping fails to write graph data, it is likely a mounted volume permission error. `start.sh` attempts to fix this on boot, but check host directory permissions if mapping to a local folder instead of a Docker volume.

**🔕 Alerts Not Firing**

Exec into the container and test the script manually:

```bash
docker exec -it smokeping_core bash
/usr/local/bin/smokeping-telegram-alert.sh "test_target" "loss" "100%"
```

---

*Maintained by Zisan*
