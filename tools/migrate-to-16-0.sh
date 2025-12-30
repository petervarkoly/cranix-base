#!/bin/bash


# NetworkManager-config-server is required as otherwise NM will immediately add connections for all interfaces, resulting in duplicates.
# NetworkManager-config-server can be removed after the migration is done.
zypper install wicked2nm NetworkManager NetworkManager-config-server || ( echo "==============Migration ERROR============="; echo "wicked2nm is not available. Migration is not possible."; exit 1 )

# If NetworkManager-config-server is not available you can also manually add the drop-in configuration.
echo -e "[main]\nno-auto-default=*" > /etc/NetworkManager/conf.d/10-server.conf

# WARNING: Run this as root, wicked will shut down the interfaces and they will only come up again once the migration is done.
# This oneliner shuts down wicked, starts NM and runs the migration, if anything went wrong it starts wicked again.
systemctl disable --now wicked \
    && (systemctl enable --now NetworkManager && wicked show-config | wicked2nm migrate --continue-migration --activate-connections -) \
    || (systemctl disable --now NetworkManager; systemctl enable --now wicked)


rm /etc/zypp/repos.d/*
rm /etc/zypp/services.d/*
sed -i 's/15.6/16.0/g' /etc/zypp/credentials.cat
echo "[CRANIX]
name=CRANIX
enabled=1
autorefresh=1
baseurl=http://repo.cephalix.eu/CRANIX/16.0
path=/
priority=10
gpgcheck=0
keeppackages=0
" > /etc/zypp/repos.d/CRANIX.repo

zypper ar https://download.opensuse.org/distribution/leap/16.0/repo/oss/ openLeap-oss
zypper ar https://download.opensuse.org/distribution/leap/16.0/repo/non-oss/ openLeap-non-oss
zypper ar http://codecs.opensuse.org/openh264/openSUSE_Leap_16 openh264

zypper refresh
# Sperren des games-Schemas
zypper addlock -t pattern games
# Sperren der KDE-spezifischen Schemata
zypper addlock -t pattern kde_games
zypper addlock -t pattern kde_office
# Sperren des kdump-Schemas
zypper addlock -t pattern kdump
# Optional: Sperren des office-Schemas
zypper addlock -t pattern office
zypper -n --releasever 16.0 dup --allow-vendor-change --no-recommends 2>&1 | tee /var/log/CRANIX-MIGRATE-TO-16.0

