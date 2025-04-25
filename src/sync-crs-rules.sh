#!/usr/bin/env sh

log() {
    DATE=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$DATE] [crs-sync] $@"
}

if [ -z "$1" ] || [ -z "$2" ]; then
    log "Usage: $0 <hostname> <server>"
    exit 1
fi

HOSTNAME="$1"
CRS_RULES_SERVER="$2"
FORCE_NO_RESTART=${3:-0}

# 1️⃣ Sync des IP bannies
BAN_FILE="/etc/modsecurity.d/banned_ips.txt"
TMP_BAN="/tmp/banned_ips.new"

fail2ban-client get modsecurity banip | tr ' ' '\n' > "$TMP_BAN" \
    || { echo "Fail while writing banned IP" >&2; exit 1; }

if [ ! -f "$BAN_FILE" ] || ! cmp -s "$TMP_BAN" "$BAN_FILE"; then
    mv "$TMP_BAN" "$BAN_FILE"
    log "banned_ips.txt updated"
    ban_changed=1
else
    log "banned_ips.txt is up to date"
    ban_changed=0
fi

# 2️⃣ Sync des CRS rules
copy_when_needed() {
    src="$1"; dst="$2"
    if [ ! -f "$dst" ] || [ "$(md5sum "$src" | cut -d' ' -f1)" != "$(md5sum "$dst" | cut -d' ' -f1)" ]; then
        cp "$src" "$dst"
        log "$dst requires update"
        return 1
    fi
    log "$dst is up to date"
    return 0
}

DST_DIR="/opt/owasp-crs/rules"
RULES_BEFORE="REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf"
RULES_AFTER="RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf"

curl -s -o /tmp/request.conf  "$CRS_RULES_SERVER/request?hostname=$HOSTNAME"
curl -s -o /tmp/response.conf "$CRS_RULES_SERVER/response?hostname=$HOSTNAME"

copy_when_needed /tmp/request.conf  "$DST_DIR/$RULES_BEFORE"; r1=$?
copy_when_needed /tmp/response.conf "$DST_DIR/$RULES_AFTER";  r2=$?

# 3️⃣ Décision de reload
restart=$(( r1 || r2 || ban_changed ))
[ "$FORCE_NO_RESTART" -eq 1 ] && { log "Forcing no restart flag"; restart=0; }

# 4️⃣ Test config & reload si besoin
nginx -t 2>&1 >/dev/null
if [ $? -ne 0 ]; then
    curl -s -o /dev/null "$CRS_RULES_SERVER/report_error?hostname=$HOSTNAME" --data "$(nginx -t 2>&1)"
    exit 1
fi

if [ "$restart" -eq 1 ]; then
    nginx -s reload && log "Reload nginx (rules/IPs updated)" || { log "Reload failed"; exit 1; }
fi
