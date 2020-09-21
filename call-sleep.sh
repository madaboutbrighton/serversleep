#!/bin/bash
#
#------------------------------------------------------------------------------
# File:         call-sleep
#
# Location:     /etc/cron.hourly/call-sleep
#
# Description:  Calls serversleep, to initiate a shutdown if certain criteria are met.
#
# Usage:        Run automatically from a cron directory.
#
# Requires:     sleep.sh
#
# Revisions:    2020-09-19 - (Mad About Brighton) Created
#
# References:   https://madaboutbrighton.net
#------------------------------------------------------------------------------

sleep.sh --torrent-level "active_downloads" --clients "192.168.1.12 192.168.1.34" --processes "cp scp rsync" --torrent-type "transmission" --torrent-password "my_torrent_password" --sony-tvs "192.168.1.67 192.168.1.89" --sony-tv-auth-psk "my_sony_psk"