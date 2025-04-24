module(load="imuxsock")    # socket local (/dev/log)
module(load="imklog")      # kernel
module(load="imudp")       # UDP
input(type="imudp" port="514")
module(load="imtcp")       # TCP
input(type="imtcp" port="514")


# forward sur TCP (@@) ou UDP (@) selon $SYSLOG_PROTO
*.* $@${SYSLOG_HOST}:${SYSLOG_PORT}
