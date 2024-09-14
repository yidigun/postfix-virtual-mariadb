#!/bin/sh

# use submission (587/tcp)
USE_SUBMISSION=${USE_SUBMISSION:-no}

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

if [ -z "$POSTFIX_MYNETWORKS" ]; then
  POSTFIX_MYNETWORKS=$(ipcalc `ip addr show scope global | grep inet | awk '{ print $2 }'` | \
                        grep -i network | awk '{ print $2 }')
  POSTFIX_MYNETWORKS=`echo $POSTFIX_MYNETWORKS | sed -e 's/ \+/, /g'`
fi
echo POSTFIX_MYNETWORKS: $POSTFIX_MYNETWORKS


# create edit commands
sedscript=/etc/postfix/mariadb.template/sedscript.sed
vars="POSTFIX_MARIADB_USERNAME \
      POSTFIX_MARIADB_PASSWORD \
      POSTFIX_MARIADB_HOST \
      POSTFIX_MARIADB_DATABASE \
      POSTFIX_MYHOSTNAME \
      POSTFIX_MYHOSTNAME_SHORT \
      POSTFIX_MYHOSTNAME_DOMAIN \
      POSTFIX_MAILNAME \
      POSTFIX_MYORIGIN \
      POSTFIX_MYNETWORKS"
cat /dev/null >$sedscript
for var in $vars; do
  # escape variables
  eval "$var=\"$(eval "echo \$$var | sed -e 's|/|\\\\/|g'")\""
  eval "echo \"s/::$var::/\$$var/g\"" >>$sedscript
done


# create config files
configs="relay_domains transport_maps virtual_domains_maps \
         virtual_alias_maps virtual_alias_domain_maps \
         virtual_alias_domain_catchall_maps virtual_mailbox_maps \
         virtual_alias_domain_mailbox_maps virtual_mailbox_limit_maps"

echo Create /etc/postfix/main.cf ...
sed -f $sedscript /etc/postfix/mariadb.template/main.cf \
        >/etc/postfix/main.cf
if [ `echo $USE_SUBMISSION | tr '[:upper:]' '[:lower:]'` = "yes" ]; then
  echo Add submission config to /etc/postfix/master.cf ...
  sed -f $sedscript /etc/postfix/mariadb.template/master.cf.submission \
          >>/etc/postfix/master.cf
fi
for config in $configs; do
  echo Create config to /etc/postfix/mariadb/$config.cf ...
  sed -f $sedscript /etc/postfix/mariadb.template/$config.cf \
        >/etc/postfix/mariadb/$config.cf
done

# Prepare chroot env
etcfiles="localtime services resolv.conf hosts nsswitch.conf nss_mdns.config"
(cd /var/spool/postfix/etc; \
for f in $etcfiles; do \
  if [ ! -f $f ]; then \
    cp /etc/$f $f; \
  fi; \
done)


CMD=$1; shift
case $CMD in
  start|run)
    exec postfix $POSTFIX_START_OPTS start-fg
    ;;

  sh|bash|/bin/sh|/bin/bash|/usr/bin/bash)
    exec /bin/bash "$@"
    ;;

  *)
    echo usage: "$0 { start [ args ... ] | sh [ args ... ] }"
    ;;

esac
