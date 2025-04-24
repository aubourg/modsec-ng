FROM owasp/modsecurity-crs:4.13.0-nginx-alpine-202504070504

USER root
RUN apk update
RUN apk add -U --no-cache git php82-fpm py3-pip supervisor --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ &&\
  pip install 'git+https://github.com/coderanger/supervisor-stdout.git' --break-system-packages

RUN apk add --no-cache rsyslog

COPY etc/ /etc/
COPY html/ /usr/share/nginx/html/

COPY sync-crs-rules.sh /sync-crs-rules.sh
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY server/rules/default/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf /opt/owasp-crs/rules
COPY server/rules/default/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf /opt/owasp-crs/rules

RUN chmod 600 /etc/nginx/conf/*

# ENV OVERRIDE_UPSTREAM_CSP="true"
# ENV MODSEC_AUDIT_ENGINE='on'
# ENV MODSEC_AUDIT_LOG_PARTS='ABCIJDEFHZ'

# ENV SYSLOG_HOST="logs.example.com"
# ENV SYSLOG_PORT="514"
# ENV SYSLOG_PROTO="@@"


RUN cp /etc/nginx/templates/conf.d/modsecurity.conf.template /etc/nginx/conf.d/modsecurity.conf

ENTRYPOINT ["/docker-entrypoint.sh"]
