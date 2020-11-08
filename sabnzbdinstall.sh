#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  Sabnzbd
# https://github.com/NasKar2/sepapps-freenas-iocage

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
JAIL_NAME=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET=""
POOL_PATH=""
APPS_PATH=""
SABNZBD_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
USE_BASEJAIL="-b"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/sabnzbd-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for sabnzbd-config and set configuration
if ! [ -e $SCRIPTPATH/sabnzbd-config ]; then
  echo "$SCRIPTPATH/sabnzbd-config must exist."
  exit 1
fi

# Check that necessary variables were set by sabnzbd-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  INTERFACE="vnet0"
  echo "INTERFACE defaulting to 'vnet0'"
fi
if [ -z $VNET ]; then
  VNET="on"
  echo "VNET defaulting to 'on'"
fi
if [ -z $POOL_PATH ]; then
  POOL_PATH="/mnt/$(iocage get -p)"
  echo "POOL_PATH defaulting to "$POOL_PATH
fi
if [ -z $APPS_PATH ]; then
  APPS_PATH="apps"
  echo "APPS_PATH defaulting to 'apps'"
fi
fi

if [ -z $JAIL_NAME ]; then
  JAIL_NAME="sabnzbd"
  echo "JAIL_NAME defaulting to 'sabnzbd'"
fi

if [ -z $SABNZBD_DATA ]; then
  SABNZBD_DATA="sabnzbd"
  echo "SABNZBD_DATA defaulting to 'sabnzbd'"
fi

if [ -z $MEDIA_LOCATION ]; then
  MEDIA_LOCATION="media"
  echo "MEDIA_LOCATION defaulting to 'media'"
fi

if [ -z $TORRENTS_LOCATION ]; then
  TORRENTS_LOCATION="torrents"
  echo "TORRENTS_LOCATION defaulting to 'torrents'"
fi

#
# Create Jail
#echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
echo '{"pkgs":["nano","ca_root_nss"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" ${USE_BASEJAIL}
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json

# fix 'libdl.so.1 missing' error in 11.1 versions, by reinstalling packages from older FreeBSD release
# source: https://forums.freenas.org/index.php?threads/openvpn-fails-in-jail-with-libdl-so-1-not-found-error.70391/
if [ "${RELEASE}" = "11.1-RELEASE" ]; then
  iocage exec ${JAIL_NAME} sed -i '' "s/quarterly/release_2/" /etc/pkg/FreeBSD.conf
  iocage exec ${JAIL_NAME} pkg update -f
  iocage exec ${JAIL_NAME} pkg upgrade -yf
fi
#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

mkdir -p ${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}'"

sabnzbd_config=${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

# create dir in jail for mount points
iocage exec ${JAIL_NAME} mkdir -p /usr/ports
iocage exec ${JAIL_NAME} mkdir -p /var/db/portsnap
iocage exec ${JAIL_NAME} mkdir -p /config
iocage exec ${JAIL_NAME} mkdir -p /mnt/media
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents

#
# mount ports so they can be accessed in the jail
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0

iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${sabnzbd_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0

iocage restart ${JAIL_NAME}
  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

#
# Install Sabnzbd
iocage exec ${JAIL_NAME} pkg install -y sabnzbdplus
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"
iocage exec ${JAIL_NAME} chown -R media:media /mnt/torrents /config
iocage exec ${JAIL_NAME} sysrc "sabnzbd_user=media"
iocage exec ${JAIL_NAME} sysrc sabnzbd_enable=YES
iocage exec ${JAIL_NAME} sysrc sabnzbd_conf_dir="/config"
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/rc.d/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/sabnzbd /usr/local/etc/rc.d/sabnzbd
#echo "sabnzbd_data ${SABNZBD_DATA}"
#iocage exec ${JAIL_NAME} sed -i '' "s/sabnzbddata/${SABNZBD_DATA}/" /usr/local/etc/rc.d/sabnzbd
#iocage exec ${JAIL_NAME} sed -i '' "s/sabnzbdpid/${SABNZBD_DATA}/" /usr/local/etc/rc.d/sabnzbd
iocage exec ${JAIL_NAME} chmod u+x /usr/local/etc/rc.d/sabnzbd
echo "**********after chmod rc.d/sabnzbd"

#
# Create directories to receive the downloads
iocage exec ${JAIL_NAME} mkdir -p /mnt/media/downloads/sabnzbd/complete
iocage exec ${JAIL_NAME} mkdir -p /mnt/media/downloads/sabnzbd/incomplete
iocage exec ${JAIL_NAME} chown -R media:media /mnt/media

echo "********service sabnzbd start"
#iocage start ${JAIL_NAME}
iocage exec ${JAIL_NAME} service sabnzbd start
echo "service sabnzbd start"
iocage exec ${JAIL_NAME} service sabnzbd stop
echo "*********service sabnzbd stop"
iocage exec ${JAIL_NAME} sed -i '' -e 's?host = 127.0.0.1?host = 0.0.0.0?g' /config/sabnzbd.ini
iocage exec ${JAIL_NAME} sed -i '' -e 's?download_dir = Downloads/incomplete?download_dir = /mnt/media/downloads/sabnzbd/incomplete?g' /config/sabnzbd.ini
iocage exec ${JAIL_NAME} sed -i '' -e 's?complete_dir = Downloads/complete?complete_dir = /mnt/media/downloads/sabnzbd/complete?g' /config/sabnzbd.ini
iocage exec ${JAIL_NAME} sed -i '' -e 's?permissions = ""?permissions = 777?g' /config/sabnzbd.ini
echo "before start after sed"
#iocage exec ${JAIL_NAME} service sabnzbd start
iocage restart ${JAIL_NAME}
echo "Sabnzbd installed"

# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf
  
# Upgrade to the lastest repo                                                                   
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

#
# remove /mnt/configs as no longer needed
iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

# Make media owner of data directories
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

echo

echo "sabnzbd should be available at http://${JAIL_IP}:8080"

