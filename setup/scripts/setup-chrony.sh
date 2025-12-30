#!/bin/bash

. /etc/sysconfig/cranix
zypper -n install chrony

echo "# CRANIX CHRONY CONF
pool 0.pool.ntp.org
ntpsigndsocket  /var/lib/samba/ntp_signd/
allow           ${CRANIX_NETWORK}/${CRANIX_NETMASK}
bindcmdaddress  ${CRANIX_SERVER}
" > /etc/chrony.d/cranix.conf


echo "base:
  '*':
    - ntp_conf" > /usr/share/cranix/templates/top.sls
echo "ntp_conf:
  ntp.managed:
    - servers:
      - admin
" > /srv/salt/ntp_conf.sls

systemctl restart chronyd
systemctl enable chronyd
sleep 10
systemctl restart samba-ad
crx_api.sh PUT softwares/saveState

