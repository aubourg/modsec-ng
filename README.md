# 🛡️ BT – ModSecurity Reverse-Proxy

Turn any HTTP / HTTPS service into a hardened, self-updating fortress.  
**Nginx + ModSecurity v3 + OWASP CRS + Fail2ban + rsyslog + Python rule-server** – everything wrapped in a single Docker-Compose stack.  
Copy → run → profit.

---

## ✨ Why you might want this

* **Instant WAF** – blocks the OWASP Top 10 out-of-the-box.  
* **Central rule server** – edit once, every proxy reloads itself.  
* **Ban list** – Fail2ban blocking IP.  

---

## 🚀 Quick start

```bash
git clone https://github.com/yourOrg/bt-modsec-proxy.git
cd bt-modsec-proxy
cp .env.sample .env        # tweak to your environment
docker compose up --build  # add -d to detach
```

Browse **http://<host>** – you’re now protected by ModSecurity.

* `docker-compose.yaml` is the production template (80/443, full logging).

---

## 🗂️ Repository layout

```
.
├── docker-compose.yaml            # production stack
├── docker-compose-example.yaml    # quick demo
└── src/                           # proxy image context
```

<details>
<summary>Click to expand <code>src/</code> highlights</summary>

| Path | Purpose |
|------|---------|
| `Dockerfile`, `docker-entrypoint.sh` | Build & start the proxy image |
| `etc/` | Nginx, ModSecurity, Fail2ban, rsyslog & Supervisor configs |
| `html/` | Custom 403, CAPTCHA page, “special” demo content |
| `sync-crs-rules.sh` | Cron script that syncs rules **and** the ban-list, then reloads Nginx |
| `server/` | Tiny Flask API distributing host-specific rule overrides |
</details>

---

## 🌐 Rule-distribution architecture

```
       🗄️  Rule server (Flask)
         └ /src/server/app.py
                ▲
      (1) /request?hostname=foo
      (2) /response?hostname=foo
                │
┌───────────────┴────────────────┐   cron: * * * * *
│ 📦  ModSecurity proxy          │──────────────────►  downloads rules
│     (runs sync-crs-rules.sh)   │                  ►  pulls Fail2ban IPs
└────────────────────────────────┘                  ►  reloads Nginx on diff
```

* `rules/` tree = one folder **per host** plus a universal **`default/`**.  
* `/report_error` receives `nginx -t` output if a bad rule blocks reload.  
* `/get_all_rules` returns a tarball backup of the whole tree.

<details>
<summary>Sync-script reload logic 🔄</summary>

1. Export Fail2ban IPs → `/etc/modsecurity.d/banned_ips.txt`  
2. `curl` the two rule files (`/request`, `/response`) for the host  
3. `md5sum` compare with live copies  
4. If bans **or** either rule changed → `nginx -t && nginx -s reload`
</details>

---

## ⚙️ Environment variables (`.env`)

| Key | Purpose (see **.env.sample** for defaults) |
|-----|--------------------------------------------|
| **Core** ||
| `HOSTNAME` | Sent to the rule server; drives per-host overrides. |
| `BACKEND_PORT443` / `BACKEND_PORT80` | Upstream HTTPS / HTTP targets. |
| `NGINX_ALWAYS_TLS_REDIRECT` | `on` → force HTTP→HTTPS 301. |
| `CAPTCHA_ON` | `1` enables the *captcha_verified* cookie flow. |
| **CRS / ModSecurity** ||
| `CRS_RULES_SYNC` + `CRS_RULES_SERVER` | Turn on auto-sync and point to the rule API. |
| `BLOCKING_PARANOIA` | CRS paranoia level **1–4**. |
| `MODSEC_REQ_BODY_LIMIT` | Max request-body size before 413. |
| **Fail2ban** ||
| `FAIL2BAN_MAXRETRY` / `FAIL2BAN_FINDTIME` / `FAIL2BAN_BANTIME` | Tune ban policy. |
| **Logging** ||
| `SYSLOG_HOST` / `SYSLOG_PORT` | Forward Nginx & ModSecurity logs. |
| `OVERRIDE_UPSTREAM_CSP` / `CSP` | Replace or set Content-Security-Policy. |

---

## 🛠️ Host-specific CRS overrides

The syncer looks for a folder named exactly like `$HOSTNAME` under `src/server/rules/`  
(or downloads it from `$CRS_RULES_SERVER`).

*Example – override for `mydemo.local`:*

```
src/server/rules/mydemo.local/
└── REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
```

The file lands inside the container at  
`/opt/owasp-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` and is active after the next cron tick (≈ 60 s).

### Disable an existing CRS rule by ID

```apache
# Disable CRS rule 920350 (numeric Host header)
SecRuleRemoveById 920350
```

### Add a custom rule

```apache
# Block /admin unless from the office subnet
SecRule REQUEST_URI "@beginsWith /admin" \
      "id:600001,phase:1,deny,log,status:403,msg:'/admin forbidden',chain"
SecRule REMOTE_ADDR "!@ipMatch 192.168.0.0/24"
```

*Use IDs outside CRS ranges, e.g. **6xxxxx** or **9xxxxx**.*

---

## 🔧 Debug tips

| Task | Command |
|------|---------|
| Trigger sync now | `docker exec -it modsec sh /sync-crs-rules.sh $HOSTNAME $CRS_RULES_SERVER` |
| View active rule file | `cat /opt/owasp-crs/rules/REQUEST-900-…` |
| Fail2ban status | `fail2ban-client status modsecurity` |
| Unban an IP | `fail2ban-client set modsecurity unbanip 1.2.3.4` |
| ModSecurity audit | `grep '"messages"' /var/log/nginx/error.log` |

---

## 📡 Rsyslog probe

```bash
sudo socat -u UDP-RECVFROM:514,reuseaddr,fork SYSTEM:'cat'
```

Confirms your log collector receives events.

---

## ➕ Extending the container

* **Add a service** – drop `start_<name>.conf` in `src/etc/supervisor.d/`.  
* **Custom SSL certs** – mount over `/etc/nginx/conf.d/ssl`.  
* **Extra ModSecurity configs** – mount into `/etc/modsecurity.d/` and reload.
