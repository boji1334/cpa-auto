# CPA Auto Deployer

<p align="center">
  <a href="#中文">中文</a> | <a href="#english">English</a>
</p>

## 中文

用于 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 的一键部署脚本。

它会自动生成 `config.yaml`、Docker Compose 文件、客户端 API Key、管理密码、持久化 `auths/` / `logs/` 目录，并可选安装 Caddy HTTPS 反向代理。

> 本仓库部署的是 CPA 主服务和 CLIProxyAPI 内置的 `/management.html` 管理面板，不默认部署 CPA Manager Plus、CPA Usage Keeper 等独立扩展组件。

### 快速开始

#### Ubuntu 服务器

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --install-docker
```

#### Ubuntu 服务器 + 域名 HTTPS

把示例域名替换成你自己的域名：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --install-docker
```

如果想自己输入管理密钥和 API Key，而不是让脚本自动生成：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --ask-secrets --install-docker
```

如果想同时安装 CPA Manager Plus 增强后台：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --with-manager-plus --manager-plus-domain manager.cpa.boji1334.com --install-docker
```

#### Ubuntu 服务器 + Cloudflare DNS

脚本会在启动 Caddy 前创建或更新 Cloudflare A 记录。默认使用 DNS-only，这样 Caddy 可以直接签发 Let's Encrypt HTTPS 证书：

```bash
export CF_API_TOKEN=cf_xxx
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo -E bash -s -- --server --domain cat.cpa.boji1334.com --cloudflare-dns --install-docker
```

Cloudflare token 只从命令环境变量读取，不会写入 `.env`、`.credentials` 或 `config.yaml`。

如果想使用 Cloudflare 橙云代理，请加上 `--cf-proxied true`，并把 Cloudflare SSL/TLS 模式设为 Full 或 Full (strict)。

#### 服务器已有 nginx / Caddy / Cloudflare Tunnel

如果服务器上已经有反向代理占用了 `80` / `443`，可以跳过本脚本自带的 Caddy：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cpa.example.com --no-caddy --install-docker
```

然后把你现有的 nginx、Caddy 或 Cloudflare Tunnel 指向：

```text
http://127.0.0.1:8317
```

#### 本地 Linux / macOS

先安装并启动 Docker，然后运行：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | bash -s -- --local
```

#### Windows 本地

先安装并启动 Docker Desktop：

[Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

然后运行 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

如果想自己输入管理密钥和 API Key：

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1 -AskSecrets"
```

### 部署后你会得到

- 监听 `8317` 端口的 CLIProxyAPI 容器。
- 可选的 Caddy HTTPS 域名反向代理。
- `/management.html` 和 `/v0/management` 使用的管理密码。
- `/v1`、`/v1beta`、`/backend-api/codex` 和 provider routes 使用的客户端 API Key。
- 持久化 `auths/` 和 `logs/` 目录。
- 辅助命令 `cpactl`。
- 保存到 `.credentials` 的访问地址、管理密码和 API Key。
- 可选 CPA Manager Plus 增强后台，包含请求监控、SQLite 用量统计、模型价格、API Key 别名等功能。

示例输出：

```text
URL:                 https://cat.cpa.boji1334.com
Management panel:    https://cat.cpa.boji1334.com/management.html
Management password: cpa-mgmt-generated
API key:             cpa-generated
```

### 常用命令

Linux / macOS：

```bash
cd /opt/cpa
./cpactl status
./cpactl logs
./cpactl manager-logs
./cpactl update
./cpactl password
./cpactl backup
```

Windows：

```powershell
cd "$env:USERPROFILE\cpa-local"
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 status
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 update
powershell -ExecutionPolicy Bypass -File .\cpactl.ps1 password
```

### 自定义选项

自定义端口：

```bash
bash install.sh --local --port 9000
```

自定义 API Key 和管理密码：

```bash
bash install.sh --local --api-key "my-api-key" --management-password "my-management-password"
```

交互式输入 API Key 和管理密码：

```bash
bash install.sh --local --ask-secrets
```

安装 CPA Manager Plus：

```bash
sudo bash install.sh --server --domain cpa.example.com --with-manager-plus --manager-plus-domain manager.cpa.example.com --install-docker
```

自定义 Manager Plus 登录 admin key：

```bash
sudo bash install.sh --server --domain cpa.example.com --with-manager-plus --manager-plus-admin-key "my-manager-admin-key" --install-docker
```

自定义服务器安装目录：

```bash
sudo bash install.sh --server --dir /opt/my-cpa --install-docker
```

暴露 OAuth 辅助回调端口：

```bash
sudo bash install.sh --server --domain cpa.example.com --oauth-ports --install-docker
```

默认情况下，OAuth 辅助回调端口 `8085`、`1455`、`54545`、`51121`、`11451` 只绑定到 `127.0.0.1`。只有当 Web 管理面板需要让 provider 登录回调直接访问服务器时，才建议使用 `--oauth-ports`。

使用已有反向代理而不是 Caddy：

```bash
sudo bash install.sh --server --domain cpa.example.com --no-caddy --install-docker
```

使用 `--no-caddy` 时，请把现有反向代理指向 `http://127.0.0.1:8317`。

### 数据位置

安装目录包含：

```text
.env                 运行变量和生成的密钥
.credentials         访问地址、管理密码、API Key
config.yaml          CLIProxyAPI 配置
docker-compose.yml   Docker Compose 配置
auths/               OAuth/auth 记录
logs/                CLIProxyAPI 日志
manager-plus-data/   CPA Manager Plus SQLite 数据和 data.key，启用 --with-manager-plus 时存在
caddy_data/          Caddy 证书数据，使用域名且未启用 --no-caddy 时存在
caddy_config/        Caddy 配置缓存，使用域名且未启用 --no-caddy 时存在
```

迁移到另一台服务器时，停止服务并复制整个安装目录即可。

### API 使用

使用生成的 API Key 作为 Bearer Token：

```bash
curl https://cat.cpa.boji1334.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

管理 API 使用管理密码：

```bash
curl https://cat.cpa.boji1334.com/v0/management/config \
  -H "Authorization: Bearer YOUR_MANAGEMENT_PASSWORD"
```

管理面板地址：

```text
https://cat.cpa.boji1334.com/management.html
```

### 可选 Manager / 统计组件

- CLIProxyAPI 官方 Web UI 是内置管理面板，服务运行后通过 `/management.html` 访问。
- CPA Manager / CPA Manager Plus 是额外的管理面板和 Manager Server，侧重更完整的配置、运行状态、用量持久化、请求监控、价格和配额视图。
- CPA Usage Keeper 是独立的用量持久化和 Dashboard 服务，通常把 CPA 的 usage queue 数据写入 SQLite。

本脚本默认只安装 CPA 主服务。加上 `--with-manager-plus` 后会安装 CPA Manager Plus，并自动开启 CPA usage queue。Manager Plus 是增强后台和监控组件，不会自动迁移 sub2api 账号；迁移账号前仍建议先备份并检查 auth/config 格式。

### 故障排查

页面打不开：

- 确认 Docker 正在运行。
- 检查 `./cpactl status` 和 `./cpactl logs`。
- 如果使用域名，确认 DNS 指向你的服务器。
- 如果使用 HTTPS，确认 TCP `80` 和 `443` 端口已开放。
- 如果使用 Cloudflare 代理，确认 SSL/TLS 模式为 Full 或 Full (strict)。

忘记凭据：

```bash
./cpactl password
```

更新 CLIProxyAPI：

```bash
./cpactl update
```

---

## English

One-command deployment helper for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI).

It generates `config.yaml`, Docker Compose files, a client API key, a management password, persistent `auths/` / `logs/` folders, and an optional Caddy HTTPS reverse proxy.

> This repository deploys the CPA core service and CLIProxyAPI's built-in `/management.html` management panel. It does not install standalone companion components such as CPA Manager Plus or CPA Usage Keeper by default.

### Quick Start

#### Ubuntu Server

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --install-docker
```

#### Ubuntu Server With Domain And HTTPS

Replace the domain with your real domain:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --install-docker
```

If you want to enter the management key and API key yourself instead of using generated values:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --ask-secrets --install-docker
```

If you also want CPA Manager Plus:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --with-manager-plus --manager-plus-domain manager.cpa.boji1334.com --install-docker
```

#### Ubuntu Server With Cloudflare DNS

This creates or updates the Cloudflare A record for the domain before starting Caddy. The script defaults the record to DNS-only, which lets Caddy issue the HTTPS certificate directly:

```bash
export CF_API_TOKEN=cf_xxx
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo -E bash -s -- --server --domain cat.cpa.boji1334.com --cloudflare-dns --install-docker
```

The Cloudflare token is read only from the command environment. It is not written to `.env`, `.credentials`, or `config.yaml`.

If you want Cloudflare orange-cloud proxy, add `--cf-proxied true` and set Cloudflare SSL/TLS mode to Full or Full (strict).

#### Server With Existing nginx / Caddy / Cloudflare Tunnel

If another reverse proxy already owns ports `80` / `443`, skip the bundled Caddy proxy:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cpa.example.com --no-caddy --install-docker
```

Then point your existing nginx, Caddy, or Cloudflare Tunnel to:

```text
http://127.0.0.1:8317
```

#### Local Linux / macOS

Install and start Docker first, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | bash -s -- --local
```

#### Windows Local

Install and start Docker Desktop first:

[Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

Then run PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

If you want to enter the management key and API key yourself:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1 -AskSecrets"
```

### What You Get

- CLIProxyAPI container on port `8317`.
- Optional Caddy HTTPS for a domain.
- Generated management password for `/management.html` and `/v0/management`.
- Generated client API key for `/v1`, `/v1beta`, `/backend-api/codex`, and provider routes.
- Persistent `auths/` and `logs/` folders.
- Helper command `cpactl`.
- URL, management password, and API key saved to `.credentials`.
- Optional CPA Manager Plus companion backend with request monitoring, SQLite usage analytics, model pricing, API key aliases, and related dashboard features.

Example output:

```text
URL:                 https://cat.cpa.boji1334.com
Management panel:    https://cat.cpa.boji1334.com/management.html
Management password: cpa-mgmt-generated
API key:             cpa-generated
```

### Common Commands

Linux / macOS:

```bash
cd /opt/cpa
./cpactl status
./cpactl logs
./cpactl manager-logs
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

### Custom Options

Custom port:

```bash
bash install.sh --local --port 9000
```

Custom API key and management password:

```bash
bash install.sh --local --api-key "my-api-key" --management-password "my-management-password"
```

Interactively enter the API key and management key:

```bash
bash install.sh --local --ask-secrets
```

Install CPA Manager Plus:

```bash
sudo bash install.sh --server --domain cpa.example.com --with-manager-plus --manager-plus-domain manager.cpa.example.com --install-docker
```

Custom Manager Plus login admin key:

```bash
sudo bash install.sh --server --domain cpa.example.com --with-manager-plus --manager-plus-admin-key "my-manager-admin-key" --install-docker
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

With `--no-caddy`, point your existing reverse proxy to `http://127.0.0.1:8317`.

### Data Location

The install directory contains:

```text
.env                 Runtime variables and generated secrets
.credentials         URL, management password, API key
config.yaml          CLIProxyAPI configuration
docker-compose.yml   Docker Compose configuration
auths/               OAuth/auth records
logs/                CLIProxyAPI logs
manager-plus-data/   CPA Manager Plus SQLite data and data.key, when using --with-manager-plus
caddy_data/          Caddy certificates, when using a domain without --no-caddy
caddy_config/        Caddy config cache, when using a domain without --no-caddy
```

To migrate to another server, stop the service and copy the whole install directory.

### API Usage

Use the generated API key as a Bearer token:

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

### Optional Manager / Usage Components

- CLIProxyAPI's official Web UI is the built-in management panel served at `/management.html`.
- CPA Manager / CPA Manager Plus are companion management panels and manager servers focused on richer configuration, runtime status, persistent usage analytics, request monitoring, pricing, and quota views.
- CPA Usage Keeper is a standalone usage persistence and dashboard service that usually consumes CPA usage queue events into SQLite.

This script installs only the CPA core service by default. With `--with-manager-plus`, it also installs CPA Manager Plus and enables the CPA usage queue. Manager Plus is a companion dashboard and monitoring service; it does not automatically migrate sub2api accounts. Back up and inspect auth/config data before migrating accounts.

### Troubleshooting

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
