#!/bin/sh

# config vars
echo POSTFIX_START_OPTS: $POSTFIX_START_OPTS
echo POSTFIX_USE_SUBMISSION: ${POSTFIX_USE_SUBMISSION:=no}
echo POSTFIX_RELAYHOST: $POSTFIX_RELAYHOST
echo POSTFIX_TLS_FULLCHAIN: $POSTFIX_TLS_FULLCHAIN
echo POSTFIX_TLS_KEYFILE: $POSTFIX_TLS_KEYFILE

echo POSTFIX_MARIADB_USERNAME: ${POSTFIX_MARIADB_USERNAME:=postfix}
: ${POSTFIX_MARIADB_PASSWORD:=postfix}
echo POSTFIX_MARIADB_PASSWORD: "$(echo $POSTFIX_MARIADB_PASSWORD | tr '[:print:]' '*')"
echo POSTFIX_MARIADB_HOST: ${POSTFIX_MARIADB_HOST:=postfix}
echo POSTFIX_MARIADB_DATABASE: ${POSTFIX_MARIADB_DATABASE:=postfix}

echo POSTFIX_MYHOSTNAME: ${POSTFIX_MYHOSTNAME:=`hostname`}
echo POSTFIX_MYHOSTNAME_SHORT: ${POSTFIX_MYHOSTNAME_SHORT:=`hostname -s`}
echo POSTFIX_MYHOSTNAME_DOMAIN: ${POSTFIX_MYHOSTNAME_DOMAIN:=`hostname -d`}

echo POSTFIX_MAILNAME: ${POSTFIX_MAILNAME:=$POSTFIX_HOSTNAME_DOMAIN}
echo $POSTFIX_MAILNAME >/etc/mailname
echo POSTFIX_MYORIGIN: ${POSTFIX_MYORIGIN:=`cat /etc/mailname`}

echo POSTFIX_MYNETWORKS: $POSTFIX_MYNETWORKS
POSTFIX_LOCALNET=$(LANG=C ipcalc `ip addr show scope global | grep inet | awk '{ print $2 }'` | \
                        grep -i network | awk '{ print $2 }')
echo POSTFIX_LOCALNET: $POSTFIX_LOCALNET
echo POSTFIX_MYORIGIN: ${POSTFIX_MYORIGIN:=`cat /etc/mailname`}


# create edit commands
sedscript=/etc/postfix/mariadb.template/sedscript.sed
vars="POSTFIX_TLS_FULLCHAIN \
      POSTFIX_TLS_KEYFILE \
      POSTFIX_RELAYHOST \
      POSTFIX_MARIADB_USERNAME \
      POSTFIX_MARIADB_PASSWORD \
      POSTFIX_MARIADB_HOST \
      POSTFIX_MARIADB_DATABASE \
      POSTFIX_MYHOSTNAME \
      POSTFIX_MYHOSTNAME_SHORT \
      POSTFIX_MYHOSTNAME_DOMAIN \
      POSTFIX_MAILNAME \
      POSTFIX_MYORIGIN \
      POSTFIX_MYNETWORKS \
      POSTFIX_LOCALNET"
cat /dev/null >$sedscript
for var in $vars; do
  # escape variables
  val=$(eval "echo \$$var | sed -e 's|/|\\\\/|g'")
  echo "s/::$var::/$val/g" >>$sedscript
done


# create config files
configs="relay_domains \
         transport_maps  \
         virtual_alias_domain_catchall_maps \
         virtual_alias_domain_mailbox_maps \
         virtual_alias_domain_maps \
         virtual_alias_maps \
         virtual_domains_maps \
         virtual_mailbox_maps"
echo Create /etc/postfix/main.cf ...
sed -f $sedscript /etc/postfix/mariadb.template/main.cf \
        >/etc/postfix/main.cf

# enable tls support
if [ -f "$POSTFIX_TLS_FULLCHAIN" -a -f "$POSTFIX_TLS_KEYFILE" ]; then
  echo Add tls support to /etc/postfix/main.cf ...
  sed -f $sedscript /etc/postfix/mariadb.template/main.cf.tls \
          >>/etc/postfix/main.cf
fi

# enable submission port (587/tcp)
if [ `echo $POSTFIX_USE_SUBMISSION | tr '[:upper:]' '[:lower:]'` = "yes" ]; then
  echo Add submission support to /etc/postfix/master.cf ...
  sed -f $sedscript /etc/postfix/mariadb.template/master.cf.submission \
          >>/etc/postfix/master.cf
fi

# create mariadb configs
for config in $configs; do
  echo Create config to /etc/postfix/mariadb/$config.cf ...
  sed -f $sedscript /etc/postfix/mariadb.template/$config.cf \
        >/etc/postfix/mariadb/$config.cf
done


# Prepare chroot env
mkdir -p /var/spool/postfix/etc &&
(cd /var/spool/postfix/etc; \
for f in localtime services resolv.conf hosts nsswitch.conf; do \
  if [ ! -f $f ]; then \
    echo Copy /etc/$f to /var/spool/postfix/etc/$f ...
    cp /etc/$f $f; \
  fi; \
done)


CMD=$1; shift
case $CMD in
  start|run)
    exec postfix $POSTFIX_START_OPTS start-fg
    ;;

  flush|reload|status)
    exec postfix -v $CMD
    ;;

  sh|bash|/bin/sh|/bin/bash|/usr/bin/bash)
    exec /bin/bash "$@"
    ;;

  *)
    echo usage: "$0 { start | flush | reload | status | sh | bash }"
    ;;

esac
