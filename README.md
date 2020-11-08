# sepapps-freenas-iocage

#### https://github.com/NasKar2/sepapps-freenas-iocage.git

Scripts to create an iocage jail on Freenas 11.1U4 from scratch in separate jails for Sonarr, Radarr, Lidarr, Tautulli and Sabnzbd

Sonarr etc. will be placed in a jail with separate data directory (/mnt/v1/apps/...) to allow for easy reinstallation/backup.

Sonarr etc. will be installed with the default user/group (media/media) and the media group will include sonarr to allow reading of the media files.

Thanks to Pentaflake for his work on installing these apps in an iocage jail.

https://forums.freenas.org/index.php?resources/fn11-1-iocage-jails-plex-tautulli-sonarr-radarr-lidarr-jackett-ombi-transmission-organizr.58/

### Prerequisites
Create file sonarr-config

## Required

- JAIL_IP: Your jail IP address
- DEFAULT_GW_IP: Your default gateway

## Optional

- INTERFACE: Defaults to 'vnet0' but can be 'ibg0' for example

- VNET: Defaults to 'on' If INTERFACE is set to 'ibg0' for example VNET should be set to 'off'

- SONARR_DATA= will create a data directory defaults to 'apps' resulting in /mnt/v1/apps/sonarr to store all the data for that app.

- MEDIA_LOCATION: will set the location of your media files, defaults to 'media' resulting in /mnt/v1/media

- TORRENTS_LOCATION: will set the location of your torrent files, defaults to 'torrents' resulting in /mnt/v1/torrents

- USE_BASEJAIL: Defaults to '-b' If you don't want a BASEJAIL set it to ""

# Minimal config file
```
JAIL_IP="192.168.5.51"
DEFAULT_GW_IP="192.168.5.1"
```

# Maximum config file
```
JAIL_IP="192.168.5.51"
DEFAULT_GW_IP="192.168.5.1"
JAIL_NAME="sonarr"
INTERFACE="igb0"
VNET="off"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
SONARR_DATA="sonarr"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"
USE_BASEJAIL=""
```

Likewise create config files for the other apps - radarr-config, lidarr-config, sabnzbd-config, tautulli-config and replace the JAIL_IP. For example see below for radarr.


Minimal radarr-config
```
JAIL_IP="192.168.5.52"
DEFAULT_GW_IP="192.168.5.1"
```

Maximum radarr-config
```
JAIL_IP="192.168.5.52"
DEFAULT_GW_IP="192.168.5.1"
JAIL_NAME="radarr"
INTERFACE="igb0"
VNET="off"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
RADARR_DATA="radarrdata"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"
USE_BASEJAIL=""
```

## Install Sonarr in fresh Jail

Create an iocage jail to install Sonarr.

Then run this command to install Sonarr
```
./sonarrinstall.sh
```

Other apps can be installed with ./AppNameinstall.sh

## After install

