#!/bin/sh

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# Check if the the CRS_RULES_SYNC env var is set to true and add a crontab entry to execute the sync script every minute.
if [ "$CRS_RULES_SYNC" = true ]; then
    entrypoint_log "$0: CRS Rules sync is enabled. Adding crontab entry to execute every minute"
    echo "* * * * * /sync-crs-rules.sh ${HOSTNAME} ${CRS_RULES_SERVER} 0 2>&1" >> /etc/crontabs/root
else
    entrypoint_log "$0: CRS rules sync is disabled"
fi

# Process all docker-entrypoint.d scripts
if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
    entrypoint_log "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

    entrypoint_log "$0: Looking for shell scripts in /docker-entrypoint.d/"
    find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
        case "$f" in
            *.envsh)
                if [ -x "$f" ]; then
                    entrypoint_log "$0: Sourcing $f";
                    . "$f"
                else
                    # warn on shell scripts without exec bit
                    entrypoint_log "$0: Ignoring $f, not executable";
                fi
                ;;
            *.sh)
                if [ -x "$f" ]; then
                    entrypoint_log "$0: Launching $f";
                    "$f"
                else
                    # warn on shell scripts without exec bit
                    entrypoint_log "$0: Ignoring $f, not executable";
                fi
                ;;
            *) entrypoint_log "$0: Ignoring $f";;
        esac
    done

    entrypoint_log "$0: Configuration complete; ready for start up"
else
    entrypoint_log "$0: No files found in /docker-entrypoint.d/, skipping configuration"
fi

# Load initial CRS RULES
if [ "$CRS_RULES_SYNC" = true ]; then
    /sync-crs-rules.sh "${HOSTNAME}" "${CRS_RULES_SERVER}" 1
fi

# Generate syslog conf 
envsubst '${SYSLOG_HOST} ${SYSLOG_PORT} ${SYSLOG_PROTO}' \
  < /etc/rsyslog.d/30-forward.conf.tpl \
  > /etc/rsyslog.d/30-forward.conf



# Start supervisord
supervisord -c /etc/supervisord.conf