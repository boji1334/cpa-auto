#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="CPA Auto"
MODE="local"
APP_DIR=""
SERVER_PORT="${SERVER_PORT:-8317}"
DOMAIN="${DOMAIN:-}"
CPA_IMAGE="${CPA_IMAGE:-eceasy/cli-proxy-api:latest}"
TIMEZONE="${TZ:-Asia/Shanghai}"
API_KEY="${API_KEY:-}"
MANAGEMENT_PASSWORD="${MANAGEMENT_PASSWORD:-}"
ASK_SECRETS="0"
INSTALL_DOCKER="0"
START_SERVICES="1"
ENABLE_OAUTH_PORTS="0"
NO_CADDY="0"
SETUP_CF_DNS="0"
CF_API_TOKEN="${CF_API_TOKEN:-${CLOUDFLARE_API_TOKEN:-}}"
CF_ZONE_ID="${CF_ZONE_ID:-}"
CF_PROXIED="${CF_PROXIED:-false}"
CF_TTL="${CF_TTL:-1}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"

usage() {
  cat <<'EOF'
CPA Auto one-click installer

Usage:
  bash install.sh --local
  sudo bash install.sh --server --install-docker
  sudo bash install.sh --server --domain cpa.example.com --install-docker

Options:
  --mode local|server     Deployment mode. local binds to 127.0.0.1, server opens to the network.
  --local                 Same as --mode local.
  --server                Same as --mode server.
  --dir PATH              Install directory. Default: ~/cpa-local or /opt/cpa.
  --port PORT             Host port for CLIProxyAPI. Default: 8317.
  --domain DOMAIN         Enable Caddy HTTPS reverse proxy for this domain.
  --api-key KEY           Client API key. Default: auto-generated.
  --management-password P Management key for /management.html and /v0/management. Default: auto-generated.
  --ask-secrets           Prompt for API key and management key interactively.
  --image IMAGE           Docker image. Default: eceasy/cli-proxy-api:latest.
  --timezone TZ           Timezone. Default: Asia/Shanghai.
  --oauth-ports           Expose OAuth helper callback ports 8085, 1455, 54545, 51121, 11451.
  --no-caddy              Do not create/start Caddy even when --domain is set.
  --cloudflare-dns        Create/update Cloudflare A record for --domain.
  --cf-token TOKEN        Cloudflare API token. Prefer CF_API_TOKEN env var.
  --cf-zone-id ZONE_ID    Cloudflare zone ID. Auto-detected from --domain if omitted.
  --cf-proxied true|false Cloudflare proxy status. Default: false.
  --install-docker        Install Docker automatically on Linux if missing.
  --no-start              Write files but do not start containers.
  -h, --help              Show this help.

Examples:
  curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | bash -s -- --local
  curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --ask-secrets --install-docker
  curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- --server --domain cat.cpa.boji1334.com --install-docker
  export CF_API_TOKEN=cf_xxx
  curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo -E bash -s -- --server --domain cat.cpa.boji1334.com --cloudflare-dns --install-docker
EOF
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --local)
      MODE="local"
      shift
      ;;
    --server)
      MODE="server"
      shift
      ;;
    --dir)
      APP_DIR="${2:-}"
      shift 2
      ;;
    --port)
      SERVER_PORT="${2:-}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:-}"
      MODE="server"
      shift 2
      ;;
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --management-password)
      MANAGEMENT_PASSWORD="${2:-}"
      shift 2
      ;;
    --ask-secrets)
      ASK_SECRETS="1"
      shift
      ;;
    --image)
      CPA_IMAGE="${2:-}"
      shift 2
      ;;
    --timezone)
      TIMEZONE="${2:-}"
      shift 2
      ;;
    --oauth-ports)
      ENABLE_OAUTH_PORTS="1"
      shift
      ;;
    --no-caddy)
      NO_CADDY="1"
      shift
      ;;
    --cloudflare-dns)
      SETUP_CF_DNS="1"
      shift
      ;;
    --cf-token)
      CF_API_TOKEN="${2:-}"
      shift 2
      ;;
    --cf-zone-id)
      CF_ZONE_ID="${2:-}"
      shift 2
      ;;
    --cf-proxied)
      CF_PROXIED="${2:-}"
      shift 2
      ;;
    --install-docker)
      INSTALL_DOCKER="1"
      shift
      ;;
    --no-start)
      START_SERVICES="0"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[ "$MODE" = "local" ] || [ "$MODE" = "server" ] || die "--mode must be local or server"
case "$SERVER_PORT" in
  ''|*[!0-9]*) die "--port must be a number" ;;
esac
case "$CF_PROXIED" in
  true|false) ;;
  *) die "--cf-proxied must be true or false" ;;
esac

if [ -z "$APP_DIR" ]; then
  if [ "$MODE" = "server" ]; then
    if [ "$(id -u)" -eq 0 ]; then
      APP_DIR="/opt/cpa"
    else
      APP_DIR="$HOME/cpa-server"
    fi
  else
    APP_DIR="$HOME/cpa-local"
  fi
fi

USE_CADDY="0"
if [ -n "$DOMAIN" ]; then
  USE_CADDY="1"
fi
if [ "$NO_CADDY" = "1" ]; then
  USE_CADDY="0"
fi

if [ "$MODE" = "local" ] || [ "$USE_CADDY" = "1" ]; then
  BIND_HOST="127.0.0.1"
else
  BIND_HOST="0.0.0.0"
fi

if [ "$SETUP_CF_DNS" = "1" ] && [ -z "$DOMAIN" ]; then
  die "--cloudflare-dns requires --domain"
fi

ensure_curl() {
  if command -v curl >/dev/null 2>&1; then
    return 0
  fi

  log "Installing curl"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ca-certificates curl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y ca-certificates curl
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache ca-certificates curl
  else
    die "curl is required and this Linux distribution is not recognized. Install curl first."
  fi
}

ensure_basic_tools() {
  ensure_curl
  if ! command -v awk >/dev/null 2>&1; then
    die "awk is required."
  fi
  if ! command -v sed >/dev/null 2>&1; then
    die "sed is required."
  fi
  if ! command -v tar >/dev/null 2>&1; then
    die "tar is required."
  fi
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker >/dev/null 2>&1 || true
  else
    service docker start >/dev/null 2>&1 || true
  fi
}

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1; then
    if ! docker info >/dev/null 2>&1 && [ "$INSTALL_DOCKER" = "1" ] && [ "$(uname -s)" = "Linux" ] && [ "$(id -u)" -eq 0 ]; then
      log "Docker is installed but not running, trying to start it"
      start_docker_service
    fi
    return 0
  fi

  [ "$INSTALL_DOCKER" = "1" ] || die "Docker is not installed. Install Docker first, or rerun with --install-docker on Linux."
  [ "$(uname -s)" = "Linux" ] || die "--install-docker only supports Linux. Install Docker Desktop manually on this system."
  [ "$(id -u)" -eq 0 ] || die "--install-docker needs root. Rerun with sudo."
  ensure_curl

  log "Installing Docker using Docker's official convenience script"
  curl -fsSL https://get.docker.com | sh
  start_docker_service
}

check_docker() {
  install_docker_if_needed
  command -v docker >/dev/null 2>&1 || die "Docker is not installed."
  if ! docker info >/dev/null 2>&1; then
    die "Docker is installed but not running. Start Docker, then rerun this script."
  fi
  if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    die "Docker Compose is missing. Install Docker Compose v2, then rerun this script."
  fi
}

compose_files() {
  if [ "$USE_CADDY" = "1" ]; then
    printf '%s\n' "-f docker-compose.yml -f docker-compose.caddy.yml"
  else
    printf '%s\n' "-f docker-compose.yml"
  fi
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    docker compose $(compose_files) "$@"
  else
    # shellcheck disable=SC2046
    docker-compose $(compose_files) "$@"
  fi
}

random_hex() {
  local bytes="$1"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
    printf '\n'
  fi
}

prompt_secret() {
  local prompt="$1"
  local value=""

  [ -r /dev/tty ] || die "--ask-secrets requires an interactive terminal. Use --api-key and --management-password for non-interactive installs."
  printf '%s' "$prompt" > /dev/tty
  if command -v stty >/dev/null 2>&1; then
    stty -echo < /dev/tty 2>/dev/null || true
  fi
  IFS= read -r value < /dev/tty || value=""
  if command -v stty >/dev/null 2>&1; then
    stty echo < /dev/tty 2>/dev/null || true
  fi
  printf '\n' > /dev/tty
  printf '%s' "$value"
}

get_env_value() {
  local key="$1"
  if [ -f .env ]; then
    awk -v k="$key" '
      index($0, k "=") == 1 {
        sub("^[^=]*=", "")
        print
        exit
      }
    ' .env
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file=".env"
  local tmp=".env.tmp"

  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    awk -v k="$key" -v v="$value" '
      index($0, k "=") == 1 { print k "=" v; next }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

server_ip_hint() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true
  fi
}

json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

cf_api() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  if [ -n "$data" ]; then
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json"
  fi
}

cf_success() {
  sed -n 's/.*"success":[[:space:]]*\(true\|false\).*/\1/p' | head -n 1
}

extract_json_string() {
  local key="$1"
  sed -n "s/.*\"${key}\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

setup_cloudflare_dns() {
  [ "$SETUP_CF_DNS" = "1" ] || return 0
  [ -n "$CF_API_TOKEN" ] || die "Cloudflare token is missing. Set CF_API_TOKEN or pass --cf-token."

  local ip
  ip="$(server_ip_hint)"
  [ -n "$ip" ] || die "Could not detect server public IP for Cloudflare DNS."

  log "Verifying Cloudflare token"
  local verify
  verify="$(cf_api GET "https://api.cloudflare.com/client/v4/user/tokens/verify")" || die "Cloudflare token verification failed."
  printf '%s' "$verify" | cf_success | grep -q '^true$' || die "Cloudflare token verification returned failure."

  if [ -z "$CF_ZONE_ID" ]; then
    local zone_name="$DOMAIN"
    local zone_resp=""
    while [ "$zone_name" != "${zone_name#*.}" ]; do
      zone_resp="$(cf_api GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}&per_page=1")" || true
      CF_ZONE_ID="$(printf '%s' "$zone_resp" | extract_json_string id)"
      if [ -n "$CF_ZONE_ID" ]; then
        break
      fi
      zone_name="${zone_name#*.}"
    done
    [ -n "$CF_ZONE_ID" ] || die "Could not auto-detect Cloudflare zone ID for ${DOMAIN}. Pass --cf-zone-id."
  fi

  local escaped_name escaped_ip payload list_resp record_id
  escaped_name="$(printf '%s' "$DOMAIN" | json_escape)"
  escaped_ip="$(printf '%s' "$ip" | json_escape)"
  payload="{\"type\":\"A\",\"name\":\"${escaped_name}\",\"content\":\"${escaped_ip}\",\"ttl\":${CF_TTL},\"proxied\":${CF_PROXIED}}"

  list_resp="$(cf_api GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${DOMAIN}&per_page=1")" || die "Cloudflare DNS lookup failed."
  record_id="$(printf '%s' "$list_resp" | extract_json_string id)"

  if [ -n "$record_id" ]; then
    log "Updating Cloudflare A record ${DOMAIN} -> ${ip}"
    cf_api PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" "$payload" | cf_success | grep -q '^true$' || die "Cloudflare DNS update failed."
  else
    log "Creating Cloudflare A record ${DOMAIN} -> ${ip}"
    cf_api POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" "$payload" | cf_success | grep -q '^true$' || die "Cloudflare DNS create failed."
  fi
}

write_compose_file() {
  cat > docker-compose.yml <<'YAML'
services:
  cli-proxy-api:
    image: "${CPA_IMAGE:-eceasy/cli-proxy-api:latest}"
    container_name: cli-proxy-api
    pull_policy: always
    restart: unless-stopped
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      MANAGEMENT_PASSWORD: "${MANAGEMENT_PASSWORD:?MANAGEMENT_PASSWORD is required}"
      DEPLOY: "${DEPLOY:-}"
    ports:
      - "${BIND_HOST:-127.0.0.1}:${SERVER_PORT:-8317}:8317"
      - "${OAUTH_BIND_HOST:-127.0.0.1}:8085:8085"
      - "${OAUTH_BIND_HOST:-127.0.0.1}:1455:1455"
      - "${OAUTH_BIND_HOST:-127.0.0.1}:54545:54545"
      - "${OAUTH_BIND_HOST:-127.0.0.1}:51121:51121"
      - "${OAUTH_BIND_HOST:-127.0.0.1}:11451:11451"
    volumes:
      - ./config.yaml:/CLIProxyAPI/config.yaml
      - ./auths:/root/.cli-proxy-api
      - ./logs:/CLIProxyAPI/logs
    healthcheck:
      test: ["CMD-SHELL", "wget -q -T 5 -O - http://127.0.0.1:8317/healthz >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
YAML
}

write_caddy_files() {
  if [ "$USE_CADDY" != "1" ]; then
    return 0
  fi

  cat > docker-compose.caddy.yml <<'YAML'
services:
  caddy:
    image: caddy:2-alpine
    container_name: cli-proxy-api-caddy
    restart: unless-stopped
    depends_on:
      - cli-proxy-api
    ports:
      - "${HTTP_PORT:-80}:80"
      - "${HTTPS_PORT:-443}:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy_data:/data
      - ./caddy_config:/config
    networks:
      - default
YAML

  cat > Caddyfile <<EOF
${DOMAIN} {
    encode gzip zstd
    reverse_proxy cli-proxy-api:8317
}
EOF
}

write_config_file() {
  cat > config.yaml <<EOF
# Generated by CPA Auto.
# Edit this file and run ./cpactl restart to apply changes.

host: ""
port: 8317

tls:
  enable: false
  cert: ""
  key: ""

remote-management:
  allow-remote: true
  secret-key: "${MANAGEMENT_PASSWORD}"
  disable-control-panel: false
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"

auth-dir: "~/.cli-proxy-api"

api-keys:
  - "${API_KEY}"

debug: false

pprof:
  enable: false
  addr: "127.0.0.1:8316"

commercial-mode: false
logging-to-file: true
logs-max-total-size-mb: 512
error-logs-max-files: 10
usage-statistics-enabled: false
redis-usage-queue-retention-seconds: 300

proxy-url: ""
force-model-prefix: false
passthrough-headers: false

request-retry: 3
max-retry-credentials: 0
max-retry-interval: 30
disable-cooling: false
disable-image-generation: false

quota-exceeded:
  switch-project: true
  switch-preview-model: true
  antigravity-credits: true

routing:
  strategy: "round-robin"
  session-affinity: false
  session-affinity-ttl: "1h"

codex:
  identity-confuse: false

ws-auth: true
enable-gemini-cli-endpoint: false
nonstream-keepalive-interval: 0
EOF
}

write_helper_script() {
  cat > cpactl <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

get_env_value() {
  key="$1"
  if [ -f .env ]; then
    awk -v k="$key" '
      index($0, k "=") == 1 {
        sub("^[^=]*=", "")
        print
        exit
      }
    ' .env
  fi
}

use_caddy() {
  domain="$(get_env_value DOMAIN)"
  [ -n "$domain" ] && [ -f docker-compose.caddy.yml ]
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    if use_caddy; then
      docker compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker compose -f docker-compose.yml "$@"
    fi
  else
    if use_caddy; then
      docker-compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker-compose -f docker-compose.yml "$@"
    fi
  fi
}

show_help() {
  cat <<'HELP'
Usage: ./cpactl COMMAND

Commands:
  start       Start CPA
  stop        Stop CPA
  restart     Restart CPA
  status      Show container status
  logs        Follow CPA logs
  update      Pull latest image and restart
  health      Check /healthz
  url         Print access URL
  password    Print saved credentials
  backup      Create a tar.gz backup in the current directory
  help        Show this help
HELP
}

case "${1:-help}" in
  start)
    compose up -d
    ;;
  stop)
    compose down
    ;;
  restart)
    compose restart
    ;;
  status)
    compose ps
    ;;
  logs)
    compose logs -f "${2:-cli-proxy-api}"
    ;;
  update)
    compose pull
    compose up -d
    ;;
  health)
    port="$(get_env_value SERVER_PORT)"
    [ -n "$port" ] || port="8317"
    curl -fsS "http://127.0.0.1:${port}/healthz"
    printf '\n'
    ;;
  url)
    domain="$(get_env_value DOMAIN)"
    mode="$(get_env_value MODE)"
    port="$(get_env_value SERVER_PORT)"
    [ -n "$port" ] || port="8317"
    if [ -n "$domain" ]; then
      printf 'https://%s\n' "$domain"
    elif [ "${mode:-local}" = "local" ]; then
      printf 'http://localhost:%s\n' "$port"
    else
      printf 'http://SERVER_IP:%s\n' "$port"
    fi
    ;;
  password)
    if [ -f .credentials ]; then
      cat .credentials
    else
      printf 'Open .env and check API_KEY / MANAGEMENT_PASSWORD.\n' >&2
      exit 1
    fi
    ;;
  backup)
    backup_file="cpa-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    paths=""
    for path in .env .credentials config.yaml docker-compose.yml docker-compose.caddy.yml Caddyfile auths logs caddy_data caddy_config; do
      if [ -e "$path" ]; then
        paths="${paths} ${path}"
      fi
    done
    if [ -z "$paths" ]; then
      printf 'Nothing to backup.\n' >&2
      exit 1
    fi
    # shellcheck disable=SC2086
    tar czf "$backup_file" $paths
    printf 'Backup created: %s\n' "$backup_file"
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$1" >&2
    show_help
    exit 1
    ;;
esac
EOF
  chmod +x cpactl
}

write_credentials() {
  local url="$1"
  cat > .credentials <<EOF
CPA_URL=${url}
MANAGEMENT_URL=${url}/management.html
API_KEY=${API_KEY}
MANAGEMENT_PASSWORD=${MANAGEMENT_PASSWORD}
INSTALL_DIR=${APP_DIR}
EOF
  chmod 600 .credentials 2>/dev/null || true
}

wait_for_health() {
  [ "$START_SERVICES" = "1" ] || return 0
  local url="http://127.0.0.1:${SERVER_PORT}/healthz"
  local i
  for i in $(seq 1 30); do
    if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  warn "CPA did not answer ${url} yet. Check ./cpactl logs."
}

ensure_basic_tools
if [ "$START_SERVICES" = "1" ]; then
  check_docker
fi
setup_cloudflare_dns

log "Preparing ${APP_NAME} in ${APP_DIR}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"
mkdir -p auths logs
if [ "$USE_CADDY" = "1" ]; then
  mkdir -p caddy_data caddy_config
fi

if [ -f .env ]; then
  backup_name=".env.backup.$(date +%Y%m%d%H%M%S)"
  cp .env "$backup_name"
  log "Existing .env found, backup saved as ${backup_name}"
else
  cat > .env <<'EOF'
# Generated by CPA Auto.
# You can edit this file and rerun ./cpactl restart.
EOF
fi

EXISTING_API_KEY="$(get_env_value API_KEY || true)"
EXISTING_MANAGEMENT_PASSWORD="$(get_env_value MANAGEMENT_PASSWORD || true)"

if [ "$ASK_SECRETS" = "1" ]; then
  if [ -z "$MANAGEMENT_PASSWORD" ]; then
    MANAGEMENT_PASSWORD="$(prompt_secret "Management key for /management.html (empty: keep existing or auto-generate): ")"
  fi
  if [ -z "$API_KEY" ]; then
    API_KEY="$(prompt_secret "Client API key for API requests (empty: keep existing or auto-generate): ")"
  fi
fi

[ -n "$API_KEY" ] || API_KEY="$EXISTING_API_KEY"
[ -n "$API_KEY" ] || API_KEY="cpa-$(random_hex 24)"
[ -n "$MANAGEMENT_PASSWORD" ] || MANAGEMENT_PASSWORD="$EXISTING_MANAGEMENT_PASSWORD"
[ -n "$MANAGEMENT_PASSWORD" ] || MANAGEMENT_PASSWORD="cpa-mgmt-$(random_hex 18)"

if [ "$ENABLE_OAUTH_PORTS" = "1" ]; then
  OAUTH_BIND_HOST="0.0.0.0"
else
  OAUTH_BIND_HOST="127.0.0.1"
fi

set_env_value MODE "$MODE"
set_env_value CPA_IMAGE "$CPA_IMAGE"
set_env_value BIND_HOST "$BIND_HOST"
set_env_value OAUTH_BIND_HOST "$OAUTH_BIND_HOST"
set_env_value SERVER_PORT "$SERVER_PORT"
set_env_value DOMAIN "$DOMAIN"
set_env_value TZ "$TIMEZONE"
set_env_value API_KEY "$API_KEY"
set_env_value MANAGEMENT_PASSWORD "$MANAGEMENT_PASSWORD"
set_env_value HTTP_PORT "$HTTP_PORT"
set_env_value HTTPS_PORT "$HTTPS_PORT"

write_config_file
write_compose_file
write_caddy_files
write_helper_script

if [ "$USE_CADDY" = "1" ]; then
  ACCESS_URL="https://${DOMAIN}"
elif [ "$MODE" = "local" ]; then
  ACCESS_URL="http://localhost:${SERVER_PORT}"
else
  PUBLIC_IP="$(server_ip_hint)"
  if [ -n "$PUBLIC_IP" ]; then
    ACCESS_URL="http://${PUBLIC_IP}:${SERVER_PORT}"
  else
    ACCESS_URL="http://SERVER_IP:${SERVER_PORT}"
  fi
fi
write_credentials "$ACCESS_URL"

if [ "$START_SERVICES" = "1" ]; then
  log "Pulling Docker images"
  compose pull
  log "Starting CPA"
  compose up -d
  log "Waiting for health check"
  wait_for_health
  log "Container status"
  compose ps
else
  warn "Files written, containers not started because --no-start was used."
fi

cat <<EOF

CPA is ready.

URL:                 ${ACCESS_URL}
Management panel:    ${ACCESS_URL}/management.html
Management password: ${MANAGEMENT_PASSWORD}
API key:             ${API_KEY}
Install dir:         ${APP_DIR}

Useful commands:
  cd ${APP_DIR}
  ./cpactl status
  ./cpactl logs
  ./cpactl update
  ./cpactl password

Credentials were saved to:
  ${APP_DIR}/.credentials
EOF

if [ "$MODE" = "server" ] && [ "$USE_CADDY" != "1" ]; then
  cat <<EOF

Server note:
  If the page is not reachable, open TCP port ${SERVER_PORT} in your cloud firewall/security group.
EOF
fi

if [ "$USE_CADDY" = "1" ]; then
  cat <<EOF

Domain note:
  Make sure ${DOMAIN} points to this server, and open TCP ports 80 and 443.
  If Cloudflare proxy is enabled, set SSL/TLS mode to Full or Full (strict).
EOF
fi

if [ "$ENABLE_OAUTH_PORTS" != "1" ]; then
  cat <<EOF

OAuth note:
  OAuth helper callback ports are bound to 127.0.0.1 by default.
  If a provider login from the web panel requires direct callback access, rerun with --oauth-ports and open the required callback port.
EOF
fi
