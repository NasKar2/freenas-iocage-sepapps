#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  Sonarr
# https://github.com/NasKar2/sepapps-freenas-iocage

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET="off"
POOL_PATH=""
APPS_PATH=""
SONARR_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""


SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/sonarr-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE="11.3-RELEASE"
#RELEASE=$(freebsd-version | sed "s/STABLE/RELEASE/g")

# Check for sonarr-config and set configuration
if ! [ -e $SCRIPTPATH/sonarr-config ]; then
  echo "$SCRIPTPATH/sonarr-config must exist."
  exit 1
fi

# Check that necessary variables were set by sonarr-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  echo 'Configuration error: INTERFACE must be set'
  exit 1
fi
if [ -z $POOL_PATH ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi

if [ -z $APPS_PATH ]; then
  echo 'Configuration error: APPS_PATH must be set'
  exit 1
fi

if [ -z $JAIL_NAME ]; then
  echo 'Configuration error: JAIL_NAME must be set'
  exit 1
fi

if [ -z $SONARR_DATA ]; then
  echo 'Configuration error: SONARR_DATA must be set'
  exit 1
fi

if [ -z $MEDIA_LOCATION ]; then
  echo 'Configuration error: MEDIA_LOCATION must be set'
  exit 1
fi

if [ -z $TORRENTS_LOCATION ]; then
  echo 'Configuration error: TORRENTS_LOCATION must be set'
  exit 1
fi

#
# Create Jail
echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
if ! iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r "${RELEASE}" ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"
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

mkdir -p ${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/videos/tvshows
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}'"
#echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}'"

sonarr_config=${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
#radarr_config=${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
#lidarr_config=${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
#sabnzbd_config=${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
#plex_config=${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
#iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
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
iocage fstab -a ${JAIL_NAME} ${sonarr_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0

iocage restart ${JAIL_NAME}
  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

#
# Install Sonarr
iocage exec ${JAIL_NAME} ln -s /usr/local/bin/mono /usr/bin/mono
iocage exec ${JAIL_NAME} "fetch http://download.sonarr.tv/v2/master/mono/NzbDrone.master.tar.gz -o /usr/local/share"
iocage exec ${JAIL_NAME} "tar -xzvf /usr/local/share/NzbDrone.master.tar.gz -C /usr/local/share"
iocage exec ${JAIL_NAME} "rm /usr/local/share/NzbDrone.master.tar.gz"
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"
iocage exec ${JAIL_NAME} chown -R media:media /usr/local/share/NzbDrone /config
iocage exec ${JAIL_NAME} -- mkdir /usr/local/etc/rc.d
iocage exec ${JAIL_NAME} cp -f /mnt/configs/sonarr /usr/local/etc/rc.d/sonarr
iocage exec ${JAIL_NAME} chmod u+x /usr/local/etc/rc.d/sonarr
iocage exec ${JAIL_NAME} sed -i '' "s/sonarrdata/${SONARR_DATA}/" /usr/local/etc/rc.d/sonarr
iocage exec ${JAIL_NAME} sysrc "sonarr_enable=YES"
iocage exec ${JAIL_NAME} service sonarr start
echo "Sonarr installed"

#
# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf

#
# Upgrade to the lastest repo
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

#
# remove /mnt/configs as no longer needed
#iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

#
# Make media owner of data directories
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

echo

echo "Sonarr should be available at http://${JAIL_IP}:8989"
echo "TV Shows will be located at "${POOL_PATH}/${MEDIA_LOCATION}/videos/tvshows
