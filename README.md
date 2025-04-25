# ModSecurity Proxy for BT

## Content Table
   * [Summary](#summary)
  * [Files and folders](#files-and-folders)
  * [CRS Rules Sync](#crs-rules-sync)
  * [Environment variables](#environment-variables)
    + [Modsecurity, Core Rules set (CRS) and NGINX](#modsecurity--core-rules-set--crs--and-nginx)
  * [Supervisor](#supervisor)
    + [Add new service to supervisor](#add-new-service-to-supervisor)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

## Summary 

This is a docker image to run a WAF as proxy based on ModSecurity and Core Rules set (CRS) official image.

## Files and folders

Using the official OWASP image for ModSecurity-CRS as a base image.
The default entrypoint has been changed to supervisord. It's configured to start nginx and php-fpm, initially.
Check the [Supervisord](#supervisord) section for more information.

**`src` directory structure:**

```
├── Dockerfile
├── docker-entrypoint.sh
├── etc
│   ├── modsecurity.d
│   │   └── modsecurity-override.conf
│   ├── nginx
│   │   └── templates
│   │       ├── conf.d
│   │       │   └── default.conf.template
│   │       └── nginx.conf.template
│   ├── supervisor.d
│   │   ├── start_crond.conf
│   │   ├── start_nginx.conf
│   │   └── start_php-fpm.conf
│   └── supervisord.conf
├── html
│   └── 403_error.php
├── server
│   ├── Dockerfile
│   ├── app.py
│   ├── docker-compose.yml
│   ├── requirements.txt
│   └── rules
│       ├── default
│       │   ├── REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
│       │   └── RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
│       └── template
│           ├── REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
│           └── RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
└── sync-crs-rules.sh

```
| File name | Description |
|-|-|
|`docker-entrypoint.sh` | entrypoint script |
|`Dockerfile` | dockerfile |
|`etc/nginx/templates/nginx.conf.template` | nginx.conf template file |
|`etc/nginx/templates/conf.d/default.conf.template` | nginx default.conf template file |
|`etc/supervisord.conf` | supervisord configuration |
|`etc/supervisor.d/start_crond.conf` | supervisor configuration for crond |
|`etc/supervisor.d/start_nginx.conf` | supervisor configuration for nginx |
|`etc/supervisor.d/start_php-fpm.conf` | supervisor configuration for php-fpm |
|`html/403_error.php` | custom error page |
|`sync-crs-rules.sh` | script to sync crs rules from a github repo |

## CRS Rules Sync

The script `/sync-crs-rules.sh` will sync the CRS rules from a CRS_RULES_SERVER.

| Name | Description|
|-|-|
| `HOSTNAME` | Hostname that will be used to query CRS_RULES_SERVER |
| `CRS_RULES_SYNC` | enable/disable the sync of the CRS rules from a github repo |
| `CRS_RULES_SERVER` | server that serves the modesec rules (example server given in src/server |
| `CRS_RULES_BRANCH` | branch name to sync the CRS rules from. default: `main`|

The CRS file are in `rules` directory and mounted in the container at `/opt/owasp-crs/rules` by `docker-compose`

## Environment variables

All the env variables are configurable in the .env file for modsecurity.

### Modsecurity, Core Rules set (CRS) and NGINX
You can set all the environment variables from the [official image](https://github.com/coreruleset/modsecurity-crs-docker)

## Supervisor

The default configuration for supervisor is in `etc/supervisord.conf`.
The plugin `supervisor-stdout` is installed to redirect the output of the processes to stdout.

### Add new service to supervisor

The supervisor load the configuration files from the folder `etc/supervisor.d`.
Configuration example file for a new service:

```
[program:nginx]
command=<command to run> # if possible use --no-daemon mode.
stdout_events_enabled = true
stderr_events_enabled = true
autostart=true
```
Copy to `etc/supervisor.d/start_<service>.conf` to allow supervisor to load the configuration.

**References:**

* [modsecurity-crs-docker](https://github.com/coreruleset/modsecurity-crs-docker)

# Rsyslog

To enable rsyslog please configure `SYSLOG_HOST` and `SYSLOG_PORT` `docker-compose.yaml`. Then you can debug if your server is receiving with :

```
sudo socat -u UDP-RECVFROM:514,reuseaddr,fork SYSTEM:'cat;echo'
```

# Fail2ban

## How to debug

Open a shell on the modsecurity container :

```
docker exec -it modsec-ng-modsec-1 sh
```

Usefull commands :

```
fail2ban-client status modsecurity # se actual status
fail2ban-client set modsecurity unbanip 192.168.10.123 # unban ip
cat /etc/modsecurity.d/banned_ips.txt # see banned ip file ( you can edit it if needed )
```