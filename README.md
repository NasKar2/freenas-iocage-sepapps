# sepapps-freenas-iocage

Scripts to create an iocage jail on Freenas 11.1U4 from scratch in separate jails for Sonarr, Radarr, Lidarr, and Sabnzbd

Sonarr etc. will be placed in a jail with separate data directory (/mnt/v1/apps/...) to allow for easy reinstallation/backup.

Sonarr etc. will be installed with the default user/group (media/media) and the media group will include sonarr to allow reading of the media files.

Thanks to Pentaflake for his work on installing these apps in an iocage jail.

https://forums.freenas.org/index.php?resources/fn11-1-iocage-jails-plex-tautulli-sonarr-radarr-lidarr-jackett-ombi-transmission-organizr.58/

### Prerequisites
Edit file sonarr-config

Edit sonarr-config file with the name of your jail, your network information and directory data name you want to use and location of your media files and torrents.

SONARR_DATA= will create a data directory /mnt/v1/apps/sonarr to store all the data for that app.

MEDIA_LOCATION will set the location of your media files, in this example /mnt/v1/media

TORRENTS_LOCATION will set the location of your torrent files, in this example /mnt/v1/torrents


```
JAIL_IP="192.168.5.51"
DEFAULT_GW_IP="192.168.5.1"
INTERFACE="igb0"
VNET="off"
POOL_PATH="/mnt/v1"
JAIL_NAME="sonarr"
SONARR_DATA="sonarrdata"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"
```

Likewise create config files for the other apps - radarr-config, lidarr-config, sabnzbd-config and replace JAIL_IP, JAIL_NAME, and JAIL_DATA with the name of the application. For example see below for radarr.

```
JAIL_IP="192.168.5.52"
DEFAULT_GW_IP="192.168.5.1"
INTERFACE="igb0"
VNET="off"
JAIL_NAME="radarr"
POOL_PATH="/mnt/v1"
APPS_PATH="apps"
RADARR_DATA>="radarrdata"
MEDIA_LOCATION="media"
TORRENTS_LOCATION="torrents"
```

## Install Sonarr in fresh Jail

Create an iocage jail to install Sonarr.

Then run this command to install Sonarr
```
./sonarrinstall.sh
```

Other apps can be installed with <appName>install.sh

## After install

