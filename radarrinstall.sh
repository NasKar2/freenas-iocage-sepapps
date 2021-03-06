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
. $SCRIPTPATH/radarr-config
CONFIGS_PATH=$SCRIPTPATH/configs
RELEASE=$(freebsd-version | cut -d - -f -1)"-RELEASE"

# Check for radarr-config and set configuration
if ! [ -e $SCRIPTPATH/radarr3-config ]; then
  echo "$SCRIPTPATH/radarr3-config must exist."
  exit 1
fi

# Check that necessary variables were set by radarr-config
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
echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
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
# update mono to 6.8.0.105
iocage exec ${JAIL_NAME} cd /tmp
iocage exec ${JAIL_NAME} pkg install -y libiconv
iocage exec ${JAIL_NAME} fetch https://github.com/jailmanager/jailmanager.github.io/releases/download/v0.0.1/mono-6.8.0.105.txz
iocage exec ${JAIL_NAME} pkg install -y mono-6.8.0.105.txz

#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

#mkdir -p ${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
mkdir -p ${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}/videos/movies
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}'"
#echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}'"
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}

#sonarr_config=${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
radarr_config=${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
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
iocage fstab -a ${JAIL_NAME} ${radarr_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0

iocage restart ${JAIL_NAME}
  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

#
# Install Radarr
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/incomplete
iocage exec ${JAIL_NAME} mkdir -p /mnt/torrents/sabnzbd/complete
iocage exec ${JAIL_NAME} ln -s /usr/local/bin/mono /usr/bin/mono
iocage exec ${JAIL_NAME} "fetch https://github.com/Radarr/Radarr/releases/download/v3.0.1.4259/Radarr.master.3.0.1.4259.linux.tar.gz -o /usr/local/share"
iocage exec ${JAIL_NAME} "tar -xzvf /usr/local/share/Radarr.master*.linux.tar.gz -C /usr/local/share"
#iocage exec ${JAIL_NAME} "rm /usr/local/share/Radarr.master*.linux.tar.gz"

#
# Make media the user of the jail and create group media and make media a user of the that group
iocage exec ${JAIL_NAME} "pw user add media -c media -u 8675309  -d /nonexistent -s /usr/bin/nologin"
#iocage exec ${JAIL_NAME} "pw groupadd -n media -g 8675309"
iocage exec ${JAIL_NAME} "pw groupmod media -m media"

#
#Install Radarr
iocage exec ${JAIL_NAME} chown -R media:media /usr/local/share/Radarr /config
iocage exec ${JAIL_NAME} -- mkdir /usr/local/etc/rc.d
iocage exec ${JAIL_NAME} cp -f /mnt/configs/radarr /usr/local/etc/rc.d/radarr
iocage exec ${JAIL_NAME} chmod u+x /usr/local/etc/rc.d/radarr
iocage exec ${JAIL_NAME} sed -i '' "s/radarrdata/${RADARR_DATA}/" /usr/local/etc/rc.d/radarr
iocage exec ${JAIL_NAME} sysrc radarr_enable="YES"
iocage exec ${JAIL_NAME} sysrc radarr_user="media"
iocage exec ${JAIL_NAME} sysrc radarr_group="media"
iocage exec ${JAIL_NAME} sysrc radarr_data_dir="/config"
iocage exec ${JAIL_NAME} service radarr start
echo "Radarr installed"

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
iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

# Make media owner of data directories
chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

echo
echo "Radarr should be available at http://${JAIL_IP}:7878"
echo "Movies will be located at "${POOL_PATH}/${MEDIA_LOCATION}/videos/movies
