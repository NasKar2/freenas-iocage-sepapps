#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  Radarr
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
RADARR_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""
USE_BASEJAIL="-b"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/radarr3-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for radarr3-config and set configuration
if ! [ -e $SCRIPTPATH/radarr3-config ]; then
  echo "$SCRIPTPATH/radarr3-config must exist."
  exit 1
fi

# Check that necessary variables were set by radarr3-config
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
  JAIL_NAME="radarr"
  echo "JAIL_NAME defaulting to 'radarr'"
fi

if [ -z $RADARR_DATA ]; then
  RADARR_DATA="radarr"
  echo "RADARR_DATA defaulting to 'radarr'"
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
  iocage exec ${JAIL_NAME} sed -i '' "s/quarterly/latest/" /etc/pkg/FreeBSD.conf
  iocage exec ${JAIL_NAME} pkg update -f
  iocage exec ${JAIL_NAME} pkg upgrade -yf

iocage exec ${JAIL_NAME} pkg install -y radarr
#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

mkdir -p /temp/downloads/sabnzbd/complete
mkdir -p ${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/videos/movies
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}'"
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}

radarr_config=${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}

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
iocage fstab -a ${JAIL_NAME} /temp /temp nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${radarr_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0


#
# Install Radarr
#iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/incomplete
#iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/complete

#
# Add user media to jail
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"

#
# Change to user media
iocage exec ${JAIL_NAME} chown -R media:media /usr/local/share/Radarr /config
iocage exec ${JAIL_NAME} sysrc radarr_enable="YES"
iocage exec ${JAIL_NAME} sysrc radarr_user="media"
iocage exec ${JAIL_NAME} sysrc radarr_group="media"
iocage exec ${JAIL_NAME} sysrc radarr_data_dir="/config"
iocage exec ${JAIL_NAME} service radarr start
echo "Radarr installed"

#
# Make media owner of data directories
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

echo
echo "Radarr should be available at http://${JAIL_IP}:7878"
echo "Movies will be located at "${POOL_PATH}/${MEDIA_LOCATION}/videos/movies
