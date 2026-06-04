# CPA Auto Deployer

One-command deployment helper for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI).

It generates `config.yaml`, Docker Compose files, a client API key, a management password, persistent auth/log folders, and optional Caddy HTTPS reverse proxy.

## Quick Start

### Ubuntu Server

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --install-docker
```

### Ubuntu Server With Domain And HTTPS

Replace the domain with your real domain:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --install-docker
```

### Ubuntu Server With Cloudflare DNS

This creates or updates the Cloudflare A record for the domain before starting Caddy. The script defaults the record to DNS-only, which lets Caddy issue the HTTPS certificate directly:

```bash
CF_API_TOKEN=cf_xxx curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo -E bash -s -- --server --domain cat.cpa.boji1334.com --cloudflare-dns --install-docker
```

The Cloudflare token is read only from the command environment. It is not written to `.env`, `.credentials`, or `config.yaml`.

If you want Cloudflare orange-cloud proxy, add `--cf-proxied true` and set Cloudflare SSL/TLS mode to Full or Full (strict).

### Local Linux / macOS

Install and start Docker first, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | bash -s -- --local
```

### Windows Local

Install and start Docker Desktop first:

[Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

Then run PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

## What You Get

- CLIProxyAPI container on port `8317`.
- Optional Caddy HTTPS for a domain.
- Generated management password for `/management.html` and `/v0/management`.
- Generated client API key for `/v1`, `/v1beta`, `/backend-api/codex`, and provider routes.
- Persistent `auths/` and `logs/` folders.
- Helper command `cpactl`.
- Credentials saved to `.credentials`.

Example output:

```text
URL:                 https://cat.cpa.boji1334.com
Management panel:    https://cat.cpa.boji1334.com/management.html
Management password: cpa-mgmt-generated
API key:             cpa-generated
```

## Common Commands

Linux / macOS:

```bash
cd /opt/cpa
./cpactl status
./cpactl logs
./cpactl update
./cpactl password
./cpactl backup
```

Windows:

```powershell
cd "$env:USERPROFILE\cpa-local"
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 status
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 update
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 password
```

## Custom Options

Custom port:

```bash
bash install.sh --local --port 9000
```

Custom API key and management password:

```bash
bash install.sh --local --api-key "my-api-key" --management-password "my-management-password"
```

Custom server directory:

```bash
sudo bash install.sh --server --dir /opt/my-cpa --install-docker
```

Expose OAuth helper ports:

```bash
sudo bash install.sh --server --domain cpa.example.com --oauth-ports --install-docker
```

By default, OAuth helper callback ports `8085`, `1455`, `54545`, `51121`, and `11451` are bound to `127.0.0.1`. Use `--oauth-ports` only when the web management panel needs provider login callbacks to reach the server directly.

Use an existing reverse proxy instead of Caddy:

```bash
sudo bash install.sh --server --domain cpa.example.com --no-caddy --install-docker
```

With `--no-caddy`, point your nginx/Caddy/Cloudflare Tunnel to `http://127.0.0.1:8317`.

## Data Location

The install directory contains:

```text
.env                 Runtime variables and generated secrets
.credentials         URL, management password, API key
config.yaml          CLIProxyAPI configuration
docker-compose.yml   Docker Compose configuration
auths/               OAuth/auth records
logs/                CLIProxyAPI logs
caddy_data/          Caddy certificates, when using a domain without --no-caddy
caddy_config/        Caddy config cache, when using a domain without --no-caddy
```

To migrate to another server, stop the service and copy the whole install directory.

## API Usage

Use the printed API key as a bearer token:

```bash
curl https://cat.cpa.boji1334.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Management API calls use the management password:

```bash
curl https://cat.cpa.boji1334.com/v0/management/config \
  -H "Authorization: Bearer YOUR_MANAGEMENT_PASSWORD"
```

The management panel is:

```text
https://cat.cpa.boji1334.com/management.html
```

## Troubleshooting

Page does not open:

- Make sure Docker is running.
- Check `./cpactl status` and `./cpactl logs`.
- If using a domain, make sure DNS points to your server.
- If using HTTPS, make sure TCP ports `80` and `443` are open.
- If using Cloudflare proxy, set SSL/TLS mode to Full or Full (strict).

Forgot credentials:

```bash
./cpactl password
```

Update CLIProxyAPI:

```bash
./cpactl update
```

---

CLIProxyAPI itself is maintained by [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI). This repository only provides a deployment wrapper.
