# Postfix Virtual Configuration for PostfixAdmin using MariaDB

```yaml
name: postfix

services:
  postfix:
    container_name: postfix
    image: docker.io/yidigun/postfix-virtual-mariadb:24.04
    restart: unless-stopped
    hostname: mail.example.com
    ports:
      - "25:25/tcp"
      - "587:587/tcp"
    environment:
      TZ: Asia/Seoul
      LANG: ko_KR.UTF-8
      USE_SUBMISSION: yes
      POSTFIX_MAILNAME: dummy.example.com
      POSTFIX_MARIADB_USERNAME: postfix
      POSTFIX_MARIADB_PASSWORD: postfix
      POSTFIX_MARIADB_HOST: mariadb.example.com
      POSTFIX_MARIADB_DATABASE: postfix
      POSTFIX_START_OPTS: "-v"

  postfixadmin:
    container_name: postfixadmin
    image: docker.io/library/postfixadmin:apache
    restart: unless-stopped
    hostname: postfix.example.com
    ports:
      - "10080:80/tcp"
    volumes:
      - "./config.local.php:/var/www/html/config.local.php"
    environment:
      TZ: Asia/Seoul
      LANG: ko_KR.UTF-8
      POSTFIXADMIN_DB_TYPE: mysqli
      POSTFIXADMIN_DB_HOST: mariadb.example.com
      POSTFIXADMIN_DB_USER: postfix
      POSTFIXADMIN_DB_NAME: postfix
      POSTFIXADMIN_DB_PASSWORD: postfix

networks:
  default:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 1450
```

```php
<?php
  $CONF['database_type'] = 'mysqli';
  $CONF['database_host'] = 'mariadb.example.com';
  $CONF['database_port'] = '3306';
  $CONF['database_user'] = 'postfix';
  $CONF['database_password'] = 'postfix';
  $CONF['database_name'] = 'postfix';
  $CONF['setup_password'] = '...create using postfixadmin setup...';
  $CONF['smtp_server'] = 'mail.example.com';
  $CONF['smtp_port'] = '25';
  $CONF['encrypt'] = 'md5crypt';
  $CONF['configured'] = true;
  $CONF['dkim'] = 'NO';
  $CONF['dkim_all_admins'] = 'NO';
```
