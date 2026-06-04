# 从 sub2api 切到 CPA 的部署和使用指南

这份文档面向已经用过 `sub2api`、准备再部署一套 `CPA / CLIProxyAPI` 的场景。重点不是把 CPA 当成另一个 sub2api 复刻版，而是说明它们的管理方式、用户接入、账号导入和日常运维有哪些不同。

本文里的示例域名使用：

```text
CPA 主服务：https://cat.cpa.boji1334.com
CPA 内置管理面板：https://cat.cpa.boji1334.com/management.html
CPA Manager Plus：https://manager.cpa.boji1334.com/management.html
OpenAI 兼容入口：https://cat.cpa.boji1334.com/v1
```

真实密钥不要写进公开 README、GitHub issue、聊天截图或用户文档。需要给用户的只应是他们自己的 API Key。

## 1. 先理解 CPA 和 sub2api 的定位差异

sub2api 更像是“面向用户订阅和分发”的服务：你会自然地想到用户、套餐、订阅链接、用户自己拿链接或 key 使用。

CPA 更像是“多账号凭据聚合 + OpenAI/Claude/Gemini/Codex 兼容代理”：核心价值是把后端登录账号、OAuth auth 文件、项目额度和模型路由集中管理，再对外暴露统一 API。

推荐你按下面的方式理解：

| 项目 | sub2api | CPA / CLIProxyAPI |
| --- | --- | --- |
| 主要用途 | 给用户分发订阅或 API 使用入口 | 聚合多个 provider 账号，统一转成兼容 API |
| 用户体系 | 通常更接近 SaaS 用户/订阅管理 | 默认不是完整用户注册系统 |
| 对外凭据 | 用户订阅/API token | `api-keys` 里的客户端 API Key |
| 后台管理 | sub2api 自身后台 | CPA 内置 `/management.html`，可选 Manager Plus |
| 账号来源 | sub2api 管理的账号/配置 | CPA `auths/` 目录里的 OAuth/auth 文件和配置 |
| 推荐发放方式 | 可按用户订阅发放 | 管理员手动给每个用户/团队分配 API Key |
| 用量统计 | 看 sub2api 自身能力 | CPA 主服务可启用 usage queue，Manager Plus 做增强展示 |
| 迁移方式 | 取决于原数据结构 | 先备份，再检查 auth 文件格式，能复用才导入 |

所以，CPA 不建议一开始就开放“用户自助注册”。更稳的运营模型是：管理员创建或维护 API Key，把某个 key 分给某个用户、团队、设备或用途，并在 Manager Plus 里给 key 设置备注/别名，方便统计和排查。

## 2. 推荐部署形态

### 2.1 最小可用部署

只部署 CPA 主服务：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- \
  --server \
  --domain cat.cpa.boji1334.com \
  --ask-secrets \
  --install-docker
```

这个模式会得到：

- CPA 主服务。
- 内置管理面板 `/management.html`。
- 一个管理密钥。
- 一个或多个客户端 API Key。
- 持久化目录 `auths/`、`logs/`。

适合先跑通、用户少、暂时不需要更细的统计后台。

### 2.2 推荐生产部署

部署 CPA 主服务 + CPA Manager Plus：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- \
  --server \
  --domain cat.cpa.boji1334.com \
  --with-manager-plus \
  --manager-plus-domain manager.cpa.boji1334.com \
  --ask-secrets \
  --install-docker
```

推荐这个模式的原因：

- CPA 主服务负责实际 API 转发和 provider 账号调度。
- 内置 `/management.html` 负责基础配置、auth 文件和服务管理。
- Manager Plus 负责更舒服的后台视图、请求监控、SQLite 用量统计、模型价格、API Key 别名等。

Manager Plus 不是另一个必须给普通用户登录的用户中心。它更适合管理员自己看，不建议开放给普通终端用户。

### 2.3 服务器已有 nginx 的部署

如果服务器已经有宝塔/nginx/Caddy/Cloudflare Tunnel 占用 `80` 和 `443`，安装时用：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/cpa-auto/main/install.sh | sudo bash -s -- \
  --server \
  --domain cat.cpa.boji1334.com \
  --no-caddy \
  --ask-secrets \
  --install-docker
```

然后把现有反向代理指向：

```text
CPA 主服务：http://127.0.0.1:8317
Manager Plus：http://127.0.0.1:18317
```

建议只让 Docker 服务监听本机 `127.0.0.1`，公网入口交给 nginx 和 HTTPS。这样和已有 sub2api 共存时更安全，也不容易抢端口。

## 3. 用户管理应该怎么做

### 3.1 不建议开放自助注册

CPA 的核心配置里是 `api-keys` 列表，不是完整的用户注册、邮箱验证、套餐购买、自动开通体系。你可以把它理解成“API Key 白名单”。

因此建议：

- 管理员手动创建 API Key。
- 一个用户、一个团队或一个用途对应一个 key。
- key 命名要有规律，例如 `u_alice_202606`、`team_xxx_prod`、`device_macbook_boji`。
- 普通用户只拿 `base_url` 和自己的 API Key，不给管理密钥。

不建议：

- 多个陌生用户共用同一个 key。
- 把管理密钥发给用户。
- 把 Manager Plus 后台当成用户自助面板。
- 在公开 GitHub 里写真实 key。

### 3.2 API Key 与管理密钥的区别

| 凭据 | 给谁 | 用途 | 泄露风险 |
| --- | --- | --- | --- |
| 客户端 API Key | 终端用户或客户端 | 调用 `/v1`、`/backend-api/codex` 等 API | 会消耗额度，可被刷请求 |
| 管理密钥 | 管理员 | 访问 `/management.html` 和管理 API | 可改配置、上传下载 auth 文件 |
| Manager Plus admin key | 管理员 | 登录 Manager Plus | 可看统计、请求和部分增强管理能力 |

普通用户只需要客户端 API Key。

### 3.3 如何新增或调整用户 key

方式一：通过内置管理面板。

1. 打开 `https://cat.cpa.boji1334.com/management.html`。
2. 用管理密钥登录。
3. 找到配置里的 `api-keys`。
4. 增加一个新的 key。
5. 保存配置并重启/应用。

方式二：直接改服务器配置。

```bash
cd /opt/cpa
nano config.yaml
./cpactl restart
```

配置形态类似：

```yaml
api-keys:
  - "user-a-key"
  - "user-b-key"
  - "team-prod-key"
```

如果安装了 Manager Plus，可以在 Manager Plus 里给 API Key 设置别名或备注，方便之后看谁用了多少、哪个 key 出问题。

## 4. 给用户怎么接入

你给普通用户的信息通常只有两项：

```text
Base URL: https://cat.cpa.boji1334.com/v1
API Key: 用户自己的 key
```

如果是 Codex 类客户端，再给：

```text
Codex endpoint: https://cat.cpa.boji1334.com/backend-api/codex
API Key: 用户自己的 key
```

不同客户端叫法不一样，常见字段是：

| 客户端字段 | 应填内容 |
| --- | --- |
| Base URL / API Base / OpenAI Base URL | `https://cat.cpa.boji1334.com/v1` |
| API Key / Token | 用户自己的 CPA API Key |
| Model | 选择 CPA 后端支持的模型名 |
| Provider | 通常选 OpenAI-compatible / Custom OpenAI / OpenAI API |

### 4.1 curl 测试

```bash
curl https://cat.cpa.boji1334.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

聊天补全示例：

```bash
curl https://cat.cpa.boji1334.com/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [
      {"role": "user", "content": "hello"}
    ]
  }'
```

模型名要以你 CPA 里实际可用的模型为准。先用 `/v1/models` 看列表。

### 4.2 OpenAI SDK

JavaScript：

```js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.CPA_API_KEY,
  baseURL: "https://cat.cpa.boji1334.com/v1",
});

const response = await client.chat.completions.create({
  model: "gpt-4o-mini",
  messages: [{ role: "user", content: "hello" }],
});

console.log(response.choices[0].message.content);
```

Python：

```python
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_API_KEY",
    base_url="https://cat.cpa.boji1334.com/v1",
)

response = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "hello"}],
)

print(response.choices[0].message.content)
```

### 4.3 本地工具怎么配置

凡是支持 OpenAI 兼容接口的工具，一般都这样填：

```bash
export OPENAI_API_KEY="YOUR_API_KEY"
export OPENAI_BASE_URL="https://cat.cpa.boji1334.com/v1"
```

有些工具不读环境变量，就在它自己的设置里填：

```text
provider: openai-compatible
base_url: https://cat.cpa.boji1334.com/v1
api_key: YOUR_API_KEY
model: 你要用的模型
```

如果工具专门支持 Codex 后端，优先看它是否允许配置 Codex API base。CPA 提供的 Codex 兼容路径通常是：

```text
https://cat.cpa.boji1334.com/backend-api/codex
```

如果工具只支持 OpenAI 兼容入口，就先用 `/v1`，不要强行填 `/backend-api/codex`。

### 4.4 要不要用 CCS

如果你说的 CCS 是 Claude Code Switch 这一类本地切换工具，它不是 CPA 必需组件。

建议选择：

| 场景 | 推荐方式 |
| --- | --- |
| 用户只用一个客户端 | 直接在客户端填 `base_url` 和 API Key |
| 用户经常在多个 API 服务之间切换 | 可以用 CCS/类似工具管理多个 endpoint |
| 用户不会配置命令行 | 给他截图或固定配置模板，不强推 CCS |
| 你要统一分发给很多人 | 写一份客户端配置模板，比让用户学额外工具更稳 |

换句话说：CPA 负责服务器端聚合和转发；CCS 只是本地客户端切换器。能直接配置 CPA 的客户端，就不需要 CCS。

## 5. 管理员后台怎么用

### 5.1 CPA 内置管理面板

地址：

```text
https://cat.cpa.boji1334.com/management.html
```

用途：

- 查看和修改 CPA 配置。
- 管理 `api-keys`。
- 管理 provider 相关配置。
- 上传、下载、删除 auth 文件。
- 查看基础状态。

这个后台使用 CPA 的管理密钥，不是客户端 API Key。

### 5.2 Manager Plus

地址：

```text
https://manager.cpa.boji1334.com/management.html
```

用途：

- 更完整的运行状态视图。
- 请求监控。
- SQLite 用量统计。
- 模型价格和费用估算。
- API Key 别名、备注和统计辅助。

Manager Plus 适合管理员使用，不建议给普通用户开放。它也不会自动把 sub2api 的用户和账号迁移进 CPA。

### 5.3 Usage Keeper 要不要装

如果已经装了 Manager Plus，通常不要再额外装 CPA Usage Keeper。

原因是 Manager Plus 已经消费 CPA 的 usage queue 做统计。多个独立统计消费者同时读同一条 usage queue，可能导致数据被其中一个服务消费走，另一个统计不完整。

## 6. 账号和 auth 文件怎么导入

CPA 后端账号不是靠给用户注册生成的，而是靠你导入 provider 登录后的 auth/OAuth 文件。这个项目的 Docker 部署会把服务器目录：

```text
/opt/cpa/auths/
```

挂载到容器里的：

```text
/root/.cli-proxy-api
```

CPA 配置里对应：

```yaml
auth-dir: "~/.cli-proxy-api"
```

### 6.1 推荐导入方式

优先用管理面板或 Manager Plus 的 Auth Files 页面导入：

1. 先在当前 sub2api 服务器上找到账号/auth 文件来源。
2. 下载或复制一份到本地临时目录。
3. 不要直接覆盖 CPA 的整个 `auths/` 目录。
4. 先在 CPA 管理面板里上传一两个 auth 文件测试。
5. 用 `/v1/models` 或一次小请求确认该账号可用。
6. 确认格式兼容后，再批量导入。

### 6.2 直接复制文件的方式

如果确认文件格式就是 CPA 能识别的 auth 文件，也可以直接放进服务器目录：

```bash
cd /opt/cpa
./cpactl backup
cp /path/to/auth-file.json ./auths/
./cpactl restart
```

然后看日志：

```bash
./cpactl logs
```

### 6.3 从 sub2api 迁移前要检查什么

迁移前先弄清楚 sub2api 里存的到底是什么：

- 是 OAuth auth JSON 文件，还是 sub2api 自己的数据库记录？
- 文件里有没有账号 access token、refresh token、project id、组织 id 等字段？
- 文件名是否会被 CPA 当作账号标识？
- 是否有 provider 类型区分，例如 OpenAI、Claude、Gemini、Codex？
- 是否有过期 token，需要重新登录？

如果 sub2api 存的是数据库，而不是 CPA 可识别的 auth 文件，就不能简单复制。需要先导出、转换或重新在 CPA 里登录账号。

### 6.4 备份优先

迁移账号前先备份 CPA：

```bash
cd /opt/cpa
./cpactl backup
```

也建议把 sub2api 的原始数据单独备份一份。不要在没有备份的情况下批量覆盖 `auths/`。

## 7. 部署后检查清单

### 7.1 服务健康

```bash
curl -fsS https://cat.cpa.boji1334.com/healthz
curl -fsS https://manager.cpa.boji1334.com/health
```

服务器本机也可以：

```bash
cd /opt/cpa
./cpactl health
./cpactl manager-health
./cpactl status
```

### 7.2 API 可用

```bash
curl https://cat.cpa.boji1334.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

如果这里报 `401` 或类似鉴权错误，优先检查：

- 用的是客户端 API Key，不是管理密钥。
- 请求头是 `Authorization: Bearer ...`。
- key 已经写入 `config.yaml` 的 `api-keys`。
- 修改配置后服务已经重启。

### 7.3 后台可用

- CPA 内置管理面板：`https://cat.cpa.boji1334.com/management.html`
- CPA Manager Plus：`https://manager.cpa.boji1334.com/management.html`

如果 Manager Plus 能打开但没统计，检查 CPA 配置里是否启用了：

```yaml
usage-statistics-enabled: true
redis-usage-queue-retention-seconds: 3600
```

使用本仓库 `--with-manager-plus` 安装时会自动设置。

## 8. 日常运维命令

进入安装目录：

```bash
cd /opt/cpa
```

查看状态：

```bash
./cpactl status
```

看 CPA 日志：

```bash
./cpactl logs
```

看 Manager Plus 日志：

```bash
./cpactl manager-logs
```

重启：

```bash
./cpactl restart
```

更新镜像并重启：

```bash
./cpactl update
```

查看安装时保存的地址和凭据：

```bash
./cpactl password
```

创建备份：

```bash
./cpactl backup
```

备份会尽量包含 `.env`、`.credentials`、`config.yaml`、`docker-compose.yml`、`auths/`、`logs/`、`manager-plus-data/` 等文件。备份包里有敏感信息，不要公开上传。

## 9. 给用户的最简说明模板

可以直接复制下面这段发给普通用户，把 key 换成给他的专属 key：

```text
你使用的是 OpenAI 兼容 API。

Base URL:
https://cat.cpa.boji1334.com/v1

API Key:
YOUR_USER_API_KEY

测试命令:
curl https://cat.cpa.boji1334.com/v1/models \
  -H "Authorization: Bearer YOUR_USER_API_KEY"

客户端里请选择 OpenAI-compatible / Custom OpenAI。
模型名以 /v1/models 返回为准。
```

如果是 Codex 类客户端：

```text
如果客户端支持 Codex API base，请使用:
https://cat.cpa.boji1334.com/backend-api/codex

如果不支持 Codex 专用入口，就使用 OpenAI 兼容入口:
https://cat.cpa.boji1334.com/v1
```

## 10. 和 sub2api 共存时的注意事项

- 不要让 CPA 和 sub2api 抢同一个宿主机端口。
- 公网只暴露 nginx/Caddy/Cloudflare Tunnel 的 HTTPS 入口。
- CPA 主服务可以绑定 `127.0.0.1:8317`。
- sub2api 可以继续绑定它原来的本机端口。
- Manager Plus 可以绑定 `127.0.0.1:18317`。
- nginx 按域名转发到不同本机端口。
- Cloudflare token 只在创建 DNS 时临时使用，不要写进仓库。

推荐域名拆分：

```text
sub2api.example.com -> 原 sub2api
cat.cpa.boji1334.com -> CPA 主服务
manager.cpa.boji1334.com -> CPA Manager Plus
```

## 11. 推荐迁移步骤

1. 先保持 sub2api 不动。
2. 部署 CPA 主服务和 Manager Plus。
3. 创建一两个测试 API Key。
4. 导入一两个测试 auth 文件。
5. 用 `/v1/models` 和简单聊天请求确认可用。
6. 给自己本地客户端改成 CPA 的 `base_url` 和 API Key。
7. 观察 Manager Plus 统计和 CPA 日志。
8. 确认稳定后，再批量导入账号。
9. 给每个用户或团队分配独立 API Key。
10. 最后再决定是否让部分用户从 sub2api 切到 CPA。

不要一上来就把 sub2api 的全部账号批量覆盖进 CPA。先小规模验证格式和额度调度，CPA 稳了再扩大。

## 12. 参考资料

- CLIProxyAPI 项目：https://github.com/router-for-me/CLIProxyAPI
- CLIProxyAPI 文档：https://help.router-for.me/
- CLIProxyAPI Management API：https://help.router-for.me/management/api
- CPA Manager Plus：https://github.com/seakee/CPA-Manager-Plus

## 13. 结论

如果目标是“像 sub2api 一样给很多普通用户自助注册、自助领取订阅”，CPA 不是最合适的第一层用户系统。

如果目标是“把多个账号集中起来，通过一个稳定的 OpenAI/Codex/Claude/Gemini 兼容 API 分发给自己或小团队使用”，CPA 很适合。你的最佳做法是：

- CPA 负责统一 API。
- Manager Plus 负责管理员后台和用量观察。
- 用户只拿自己的 API Key。
- 账号迁移先备份、先单个测试、再批量导入。
