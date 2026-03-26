---
name: sdt-server
description: Complete knowledge of the SDT proxy server — SSH access, file paths, deployment, endpoints, architecture. Use whenever working with the proxy server, deploying changes, or debugging server issues.
license: MIT
metadata:
  author: Pavel Kulitski
  version: "1.0"
---

# SDT Proxy Server — Complete Reference

## Connection

```bash
ssh root@178.104.87.2
```

No password needed — SSH key `~/.ssh/id_ed25519` is already authorised on the server.

## Server Facts

| Property | Value |
|---|---|
| Provider | Hetzner CAX11 (Нюрнберг, ARM64) |
| IP | 178.104.87.2 |
| Domain | sdtapi.mooo.com |
| OS | Ubuntu 24.04 LTS |
| Cost | ~€4/мес |
| Node.js | v20 |
| Process manager | PM2 (auto-restart, survives reboot) |
| Reverse proxy | Caddy 2 (auto HTTPS via Let's Encrypt) |
| Firewall | UFW — ports 22, 80, 443 only |

## File Paths on Server

```
/root/sdt-proxy/
├── src/
│   ├── index.ts        — routes: /api/chat, /api/generate, /api/evaluate, /api/breadth
│   ├── auth.ts         — HMAC-SHA256 signature validation middleware
│   ├── rateLimit.ts    — per-device daily rate limiting (in-memory Map)
│   ├── providers.ts    — Claude / OpenAI / Gemini clients (with systemPrompt support)
│   ├── prompts.ts      — server-side prompt builders (generation, evaluation, breadth)
│   └── cache.ts        — TTL cache (8h) for /api/generate responses
├── .env                — API keys + APP_SECRET (NEVER commit)
└── package.json
/etc/caddy/Caddyfile    — HTTPS reverse proxy config
```

## Local Source (Mac)

```
~/Desktop/sdt-proxy/src/   ← edit here, then deploy
```

## Deploy (update code on server)

```bash
# 1. Upload changed files from Mac
scp -r ~/Desktop/sdt-proxy/src root@178.104.87.2:/root/sdt-proxy/

# 2. Restart app
ssh root@178.104.87.2 "pm2 restart sdt-proxy"

# 3. Verify
curl https://sdtapi.mooo.com/health
# Expected: {"status":"ok","ts":...,"cacheSize":N}
```

Claude Code can run all three commands directly — no user involvement needed.

## PM2 Commands (run via SSH)

```bash
pm2 status                          # process list
pm2 logs sdt-proxy --lines 50       # last 50 log lines
pm2 restart sdt-proxy               # restart after code change
pm2 reload sdt-proxy                # zero-downtime reload
systemctl restart caddy             # restart HTTPS proxy if needed
```

## API Endpoints

All `/api/*` routes require:
- `X-App-Signature: HMAC-SHA256(rawBody, APP_SECRET)` — hex string
- `X-Device-ID: <UUID>` — stable per-device identifier
- `X-Is-Pro: "1" | "0"` — subscription status

### GET /health
No auth. Returns `{"status":"ok","ts":N,"cacheSize":N}`.

### POST /api/chat  (legacy, kept for direct-key users)
Raw prompt forwarding. Body: `{ provider, model, maxTokens, prompt }`.

### POST /api/generate  ← primary generation endpoint
Builds prompt server-side + TTL cache (8h). Cache bypassed when `recentQuestions` supplied.

Body:
```json
{
  "provider": "claude",
  "model": "claude-haiku-4-5-20251001",
  "skillName": "Swift ARC",
  "category": "programming",
  "difficulty": 3,
  "healthScore": 0.42,
  "language": "en",
  "count": 3,
  "recentQuestions": ["optional question texts to avoid"]
}
```
Response: `{ "content": "[{...}]", "cached": true|false, "tokens": { "input": N, "output": N } }`

### POST /api/evaluate  ← subjective answer evaluation
Body:
```json
{
  "provider": "claude",
  "model": "claude-haiku-4-5-20251001",
  "challengeType": "open_ended",
  "question": "...",
  "correctAnswer": "...",
  "explanation": "...",
  "skillContext": "...",
  "userAnswer": "...",
  "language": "en"
}
```
Response: `{ "content": "{\"is_correct\":true,\"feedback\":\"...\",\"confidence_hint\":\"high\"}", "tokens": {...} }`

### POST /api/breadth  ← skill breadth analysis
Body: `{ provider, model, skillName, context, category, language }`
Response: `{ "content": "{\"subSkills\":[...]}", "tokens": {...} }`

## Rate Limits (per device per 24h)

| User type | Limit |
|---|---|
| Free | 30 requests/day |
| Pro | 300 requests/day |
| No Device-ID | 5 requests/day |

## Security

- **HMAC-SHA256** — `APP_SECRET` shared between iOS app (`ProxyAPIClient.appSecret`) and server `.env`
- Current `appSecret` in iOS: `689c56112204cb20c351881782fcd001901822eccfd4d5ae9010de51922d5628`
- Server `.env` must have `APP_SECRET=` with the same value

## Environment Variables (.env on server)

```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-proj-...
GEMINI_API_KEY=AIza...
APP_SECRET=689c56112204cb20c351881782fcd001901822eccfd4d5ae9010de51922d5628
RATE_LIMIT_FREE=30
RATE_LIMIT_PRO=300
PORT=3000
```

## Check Spend / Logs

```bash
# Requests count today
ssh root@178.104.87.2 "pm2 logs sdt-proxy --nostream --lines 9999 | grep 'POST /api/' | wc -l"

# Live logs
ssh root@178.104.87.2 "pm2 logs sdt-proxy"
```

Anthropic spend: console.anthropic.com → Usage

## Scaling Notes

- < 500 DAU → current server fine, no changes needed
- 500–2000 DAU → `pm2 start "npm run start" --name sdt-proxy -i max` (cluster mode)
- Cache hit rate 60–80% → effective token cost drops by same margin
- Redis not needed until horizontal scaling (10k+ DAU)
