#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  Lidarr
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
LIDARR_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
USE_BASEJAIL="-b"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/lidarr-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for lidarr-config and set configuration
if ! [ -e $SCRIPTPATH/lidarr-config ]; then
  echo "$SCRIPTPATH/lidarr-config must exist."
  exit 1
fi

# Check that necessary variables were set by lidarr-config
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
if [ -z $JAIL_NAME ]; then
  JAIL_NAME="lidarr"
  echo "JAIL_NAME defaulting to 'lidarr'"
fi

if [ -z $LIDARR_DATA ]; then
  LIDARR_DATA="lidarr"
  echo "LIDARR_DATA defaulting to 'lidarr'"
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
echo '{"pkgs":["nano"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" allow_mlock="1" allow_raw_sockets="1" host_hostname="${JAIL_NAME}" vnet="${VNET}" ${USE_BASEJAIL} allow_mlock=1 allow_raw_sockets=1
then
	echo "Failed to create jail"
	exit 1
fi
rm /tmp/pkg.json
#
# Update pkg
  iocage exec ${JAIL_NAME} "mkdir -p /usr/local/etc/pkg/repos/"
  iocage exec ${JAIL_NAME} cp /etc/pkg/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf
  iocage exec ${JAIL_NAME} sed -i '' "s/quarterly/latest/" /usr/local/etc/pkg/repos/FreeBSD.conf
  iocage exec ${JAIL_NAME} pkg update -f
  iocage exec ${JAIL_NAME} pkg upgrade -yf

iocage exec ${JAIL_NAME} pkg install -y lidarr
#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db
mkdir -p ${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/music
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
mkdir -p ${POOL_PATH}/temp/downloads/sabnzbd/complete/music/

echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}'"
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}

lidarr_config=${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}

# create dir in jail for mount points
iocage exec ${JAIL_NAME} mkdir -p /usr/ports
iocage exec ${JAIL_NAME} mkdir -p /var/db/portsnap
iocage exec ${JAIL_NAME} mkdir -p /config
iocage exec ${JAIL_NAME} mkdir -p /mnt/${MEDIA_LOCATION}
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents
iocage exec ${JAIL_NAME} "mkdir -p /mnt/temp/downloads/sabnzbd/complete/music"

#
# mount ports so they can be accessed in the jail
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} /temp /temp nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${lidarr_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/${MEDIA_LOCATION} nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/temp/downloads/sabnzbd/complete/music /mnt/temp/downloads/sabnzbd/complete/music nullfs rw 0 0

#
# Install Lidarr
#iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/incomplete
#iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/complete

#
# Add user media to jail
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"

#
# Change to user media
iocage exec ${JAIL_NAME} chown -R media:media /config
iocage exec ${JAIL_NAME} sysrc lidarr_enable="YES"
iocage exec ${JAIL_NAME} sysrc lidarr_user="media"
iocage exec ${JAIL_NAME} sysrc lidarr_group="media"
iocage exec ${JAIL_NAME} sysrc lidarr_data_dir="/config"
iocage exec ${JAIL_NAME} service lidarr start
echo "Lidarr installed"

#
# Make media owner of data directories
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

echo
echo "Lidarr should be available at http://${JAIL_IP}:8686"
echo "Movies will be located at "${POOL_PATH}/${MEDIA_LOCATION}/music
