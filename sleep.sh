#!/bin/bash
#
#------------------------------------------------------------------------------
# File:         serversleep
#
# Location:     /usr/local/bin/serversleep
#
# Description:  Shuts down a computer if certain criteria are met:-
#                 - None of the listed clients are active.
#                 - None of the listed processes are active.
#                 - None of the listed Sony TVs are active.
#                 - No users logged-on.
#                 - No torrents are active, such as downloading or seeding.
#                 - No TV tuner is active, such as recording or streaming.
#
# Usage:        serversleep -v --clients "192.168.1.15" --processes "cp mv"
#
# Requires:     cURL
#
# Revisions:    2020-09-16 - (Mad About Brighton) Created
#
# References:   https://madaboutbrighton.net
#------------------------------------------------------------------------------

# Default options.
is_dry_run=0
is_verbose=0
# Minimum time in seconds needed to start up the computer properly.
safe_margin_startup=180
# Minimum time in seconds needed for consecutive shutdown AND startup.
safe_margin_shutdown=600
# RTC folder, for setting an alarm to wake the computer.
rtc_folder="/sys/class/rtc/rtc0"
clients=""
processes="cp mv rsync scp"
# Sony TV settings
sony_tvs=""
sony_tv_auth_psk=""
# Torrent software settings
torrent_type=""
torrent_level=""
torrent_user=""
torrent_password=""
# TV Tuner software settings
tv_tuner_type=""
tv_tuner_login=""
tv_tuner_password=""
# Maximum time in hours not to wake up for updating EPG
tv_tuner_epg_hours=48

notify=""

#######################################
# Sets the commandline arguments as global variables.
# Globals:
#   is_dry_run, is_recursive, is_verbose, is_move, 
#   path_source, path_dest, notify
# Arguments:
#   The commandline arguments, a string.
# Example:
#   get_options "$@"
#######################################
get_options() {
  while getopts "nt:v-:" opt; do
      case "${opt}" in
      -)
        case "${OPTARG}" in
          safe-margin-startup)
            safe_margin_startup="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          safe-margin-shutdown)
            safe_margin_shutdown="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          rtc-folder)
            rtc_folder="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          clients)
            clients="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          processes)
            processes="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          sony-tvs)
            sony_tvs="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          sony-tv-auth-psk)
            sony_tv_auth_psk="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          torrent-level)
            torrent_level="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          torrent-user)
            torrent_user="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          torrent-password)
            torrent_password="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          torrent-type)
            torrent_type="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          tv-tuner-type)
            tv_tuner_type="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          tv-tuner-login)
            tv_tuner_login="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          tv-tuner-password)
            tv_tuner_password="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          tv-tuner-epg-hours)
            tv_tuner_epg_hours="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
          *)
            if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                echo "Unknown option --${OPTARG}" >&2
            fi
            ;;
        esac;;      
      t)
        notify="${OPTARG}"
        ;;
      v)
        is_verbose=1
        ;;
      n)
        is_dry_run=1
        ;;
      esac
  done
  
  shift $(($OPTIND - 1))
      
  # Show all the arguments/options when [is_dry_run].
  if [ "${is_dry_run}" -eq 1 ]; then
    message "[SETTINGS]"
    message "is_dry_run=${is_dry_run}"
    message "is_verbose=${is_verbose}"
    message "notify=${notify}"
    message "safe_margin_startup=${safe_margin_startup} seconds"
    message "safe_margin_shutdown=${safe_margin_shutdown} seconds"
    message "rtc_folder=${rtc_folder}"
    message "processes=${processes}"
    message "clients=${clients}"
    message "[SONY_TV]"
    message "sony_tvs=${sony_tvs}"
    message "sony_tv_auth_psk=${sony_tv_auth_psk}"
    message "[TORRENT]"
    message "torrent_type=${torrent_type}"
    message "torrent_user=${torrent_user}"
    message "torrent_password=${torrent_password}"
    message "torrent_level=${torrent_level}"
    message "[TV TUNER]"
    message "tv_tuner_type=${tv_tuner_type}"
    message "tv_tuner_login=${tv_tuner_login}"
    message "tv_tuner_password=${tv_tuner_password}"
    message "tv_tuner_epg_hours=${tv_tuner_epg_hours}\n"
  fi
}

#######################################
# Outputs a message, even if not [is_verbose].
# Arguments: 
#   The message to be displayed, a string.
# Example:
#   err "My error message"
#######################################
err() {
  echo -e "$*" >&2
}

#######################################
# Outputs a message, when [is_verbose] or [is_dry_run].
# Globals:
#   is_dry_run, is_verbose
# Arguments: 
#   The message to be displayed, a string.
# Example:
#   message "My message"
#######################################
message() {
  if [ "${is_verbose}" -eq 1 ] || [ "${is_dry_run}" -eq 1 ]; then
    echo -e "$*" >&2
  fi
}

#######################################
# Sends a message to a service.
# Arguments: 
#   The name of the sender, a string.
#   The reciever, a string.
#   The message to be displayed, a string.
# Example:
#   notify "myscript" "https://hooks.slack.com/services/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" "The script is complete!"
#######################################
notify() {
  local -r FROM="${1}"
  local -r TO="${2}"
  local -r MESSAGE="${3}"

  # Check if the reciever is a Slack Webhook URL.
  if [[ $TO =~ "hooks.slack.com" ]]; then
     $(notify_slack "${FROM}" "${TO}" "${MESSAGE}" &> /dev/null)
  fi
}

#######################################
# Sends a message to a Slack.
# Arguments: 
#   The name of the sender, a string.
#   The Webhook URL, a string.
#   The message to be displayed, a string.
# References:
#   https://api.slack.com/messaging/webhooks
# Example:
#   notify_slack "myscript" "https://hooks.slack.com/services/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" "The script is complete!"
#######################################
notify_slack() {
  local -r FROM="${1}"
  local -r WEBHOOK_URL="${2}"
  local -r MESSAGE="${3}"

  curl -X POST -sH 'Content-type: application/json' --data '{"blocks": [{"type": "section","text": {"type": "mrkdwn","text": ":memo: *'"${FROM}"'*: '"${MESSAGE}"'"}}]}' "${WEBHOOK_URL}"
}

#######################################
# Trim the leading and trailing whitespace from a string.
# Arguments:
#   The string to be trimmed.
# Returns:
#   The trimmed string.
# Example:
#   trim "    here is my long string    "
# Source:
#   blujay @ https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
#######################################
trim() {
  if [[ "${1}" =~ ^[[:space:]]*([^[:space:]].*[^[:space:]])[[:space:]]*$ ]]; then 
    echo "${BASH_REMATCH[1]}"
  fi
}

#######################################
# Checks whether any computers are awake by pinging them.
# Arguments:
#   The IP addresses to be checked, a space seperated string.
# Returns:
#   The total number of IP addresses found to be awake.
# Example:
#   check_clients "192.168.89.123 192.168.24.321"
#######################################
check_clients() {
  local -r CLIENTS="${1}"
  # Create an array of the IP addresses.
  local ips=($CLIENTS)
  local text=""
  # Reset the counters.
  local counter=0
  local total=0
  
  if [ -n "${CLIENTS}" ]; then
    message "Checking for active clients (${CLIENTS})..."
    
    for ip in "${ips[@]}"; do
      ip=$(trim "${ip}")
      
      if [ ! -z "${ip}" ]; then
        # Ping an IP address. 
        counter=$(ping -c1 $ip | grep 'received' | awk -F ',' '{print $2}' | awk '{ print $1}')
        if [ $counter -gt 0 ]; then
          # Ping was successful, so print the IP address and increment the counter.
          message "${ip}"
          total=$((total+1))
        fi
      fi;
    done
    
    # Print a useful message depending upon the number of active IP addresses.
    case $total in
    0)
      text="No active clients found."
      ;;
    1)
      text="1 active client found."
      ;;
    *)
      text="${total} active clients found."
      ;;
    esac
    
    message "${text}\n"
  fi
  
  # Return the total number of active IP addresses.
  echo "${total}"
}

#######################################
# Checks whether any processes are running.
# Arguments:
#   The names of the processes to be checked, a space seperated string. Case insensitive.
# Returns:
#   The total number of processes found to be running.
# Example:
#   check_processes "cp scp"
#######################################
check_processes() {
  local -r PROCESSES="${1}"
  # Create an array of the processes.
  local processes=($PROCESSES)
  local text=""
  # Reset the counters.
  local counter=0
  local total=0
  
  if [ -n "${PROCESSES}" ]; then
    message "Checking for running processes (${PROCESSES})..."
    
    for process in "${processes[@]}"; do
      process=$(trim "${process}")
            
      if [ ! -z "${process}" ]; then
        # Check for the runnning process. Case insensitive. 
        counter=($(ps -A | grep -iE "(^|\s)${process}($|\s)" | wc -l))
        if [ $counter -gt 0 ]; then
          # Matching processes found, so print the process name and increment the counter.
          message "${process}"
          total=$((total+counter))
        fi
      fi;
    done
    
    # Print a useful message depending upon the number of running processes found.
    case $total in
    0)
      text="No running processes found."
      ;;
    1)
      text="1 running process found."
      ;;
    *)
      text="${total} running processes found."
      ;;
    esac
    
    message "${text}\n"
  fi
  
  # Return the total number of running processes.
  echo "${total}"
}

#######################################
# Checks whether any Sony TVs are awake by querying their power status.
# The TVs are not simply pinged, as they may respond even when on stand-by.
# Arguments:
#   The TV IP addresses to be checked, a space seperated string.
#   The pre-shared key (PSK) or password of the tv, a string.
# Returns:
#   The total number of TVs found to be awake.
# Example:
#   check_sony_tvs "192.168.89.789 192.168.24.987" "my_tv_psk"
#######################################
check_sony_tvs() {
  local -r TVS="${1}"
  local -r AUTH_PSK="${2}"
  # Create an array of the IP addresses.
  local ips=($TVS)
  local text=""
  # Reset the counters.
  local counter=0
  local total=0
  
  if [ -n "${TVS}" ]; then
    message "Checking for active Sony TVs (${TVS})..."
    
    for ip in "${ips[@]}"; do
      ip=$(trim "${ip}")
      
      if [ ! -z "${ip}" ]; then
        # Ping an IP address. 
        counter=$(curl -s -X POST -H "Content-Type: application/json" -H "X-Auth-PSK: $AUTH_PSK" -d '{"id":3,"method":"getPowerStatus","version":"1.0","params":[]}' http://$ip/sony/system | grep '"active"' | wc -l)
        if [ $counter -gt 0 ]; then
          # Ping was successful, so print the TV IP address and increment the counter.
          message "${ip}"
          total=$((total+1))
        fi
      fi;
    done
    
    # Print a useful message depending upon the number of active TVs.
    case $total in
    0)
      text="No active Sony TVs found."
      ;;
    1)
      text="1 active Sony TV found."
      ;;
    *)
      text="${total} active Sony TVs found."
      ;;
    esac
    
    message "${text}\n"
  fi
  
  # Return the total number of active TVs.
  echo "${total}"
}

#######################################
# Checks whether any users are currently active.
# Returns:
#   The total number of active users found.
# Example:
#   check_users
#######################################
check_users() {
  local text=""
  # Reset the counters.
  local total=0
  
  message "Checking for active users..."
    
  total=$(who | wc -l)
    
  if [ $total -gt 0 ]; then
    # Active users found, so print their names.
    message $(who | awk '{print $1}')
  fi
  
  # Print a useful message depending upon the number of active users.
  case $total in
  0)
    text="No active users found."
    ;;
  1)
    text="1 active user found."
    ;;
  *)
    text="${total} active users found."
    ;;
  esac
  
  message "${text}\n"
  
  # Return the total number of active users.
  echo "${total}"
}

#######################################
# Checks for torrents.
# Arguments:
#   The type of the torrent client, a string. Currently only supports "transmission".
#   The torrent client username, a string.
#   The torrent client password, a string.
#   The torrent level, a string. Currently only supports "active" and "active_downloads".
#     - active - includes torrents being downloaded and seeded.
#     - active_downloads - only includes torrents being downloaded. 
# Returns:
#   The total number of torrents found within the specified torrent level.
# Example:
#   check_torrents "transmission" "my_username" "my_password" "active_downloads"
#######################################
check_torrents() {
  local -r TORRENT_TYPE="${1}"
  local -r TORRENT_USER="${2}"
  local -r TORRENT_PASSWORD="${3}"
  local -r TORRENT_LEVEL="${4}"
  local text=""
  # Reset the counters.
  local total=0
  
  if [[ -n "${TORRENT_TYPE}" ]] && [[ -n "${TORRENT_LEVEL}" ]]; then

    message "Checking for torrents (${TORRENT_TYPE})..."
    
    # Print a useful message depending upon the number of torrents found.
    case $TORRENT_TYPE in
    transmission)
      if [ "${TORRENT_LEVEL}" = "active" ]; then
        # Check for torrents that are downloading or being seeded. 
        total=($(transmission-remote --auth transmission:$TORRENT_PASSWORD --list 2> /dev/null | sed '1d;$d' | grep -v Stopped | grep -v Idle | grep -v Finished | wc -l))
      elif [ "${TORRENT_LEVEL}" = "active_downloads" ]; then
        # Check for torrents that are being downloaded. 
        total=($(transmission-remote --auth transmission:$TORRENT_PASSWORD --list 2> /dev/null | sed '1d;$d' | grep -v Stopped | grep -v Idle | grep -v Seeding | grep -v Finished | wc -l))
      else
        err "Torrent level ${TORRENT_LEVEL} not found."
      fi
      ;;
    *)
      err "Torrent type ${TORRENT_TYPE} not found."
      ;;
    esac

    # Print a useful message depending upon the number of torrents found.
    case $total in
    0)
      text="No torrents found."
      ;;
    1)
      text="1 torrent found."
      ;;
    *)
      text="${total} torrents found."
      ;;
    esac
    
    message "${text}\n"
  fi
  
  # Return the total number of matching torrents.
  echo "${total}"
}

#######################################
# Checks for current and future tv tuner activity.
# If planned activity is found, then a timer is set to wake up the computer.
# Arguments:
#   The type of the tv tuner, a string. Currently only supports "tvheadend".
#   The tv tuner username, a string.
#   The tv tuner password, a string.
#   Minimum time in seconds needed to start-up the computer properly, an integer.
#   Minimum time in seconds needed for consecutive shutdown AND start-up, an integer.
#   Maximum time in hours not to wake-up for updating EPG.
#   RTC folder, for setting an alarm to wake the computer, a string.
# Returns:
#   Whether there is current activity, an integer. 
# Example:
#   check_tv_tuner "tvheadend" "my_username" "my_password" 180 600
#######################################
check_tv_tuner() {
  local -r TUNER_TYPE="${1}"
  local -r TUNER_USER="${2}"
  local -r TUNER_PASSWORD="${3}"
  local -r SAFE_MARGIN_STARTUP="${4}"
  local -r SAFE_MARGIN_SHUTDOWN="${5}"
  local -r EPG_HOURS="${6}"
  local -r RTC_FOLDER="${7}"
  local text=""
  local is_active=0
  local wake_after_min=0
  local wake_after_min_temp=0
  
  if [ -n "${TUNER_TYPE}" ]; then

    message "Checking for TV tuner activity (${TUNER_TYPE})..."
    
    # Print a useful message depending upon the number of torrents found.
    case $TUNER_TYPE in
    tvheadend)
      # Check for tvheadend activity - recording, streaming etc.
      local total_tvheadend=$(curl -s --user $TUNER_USER:$TUNER_PASSWORD http://127.0.0.1:9981/status.xml | grep "subscriptions" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
      # Make sure something was returned.
      if [ -n "${total_tvheadend}" ]; then
        if [ $total_tvheadend -gt 0 ]; then
          # Activity found.
          is_active=1
        else
          # No activity found, so check for future events.
          wake_after_min=$((EPG_HOURS*60))
          if [ $(curl -s --user $TUNER_USER:$TUNER_PASSWORD 127.0.0.1:9981/status.xml | grep "next" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | wc -l) -gt 0 ]; then
            wake_after_min_temp=$(curl -s --user $TUNER_USER:$TUNER_PASSWORD 127.0.0.1:9981/status.xml | grep "next" | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
            if [ $wake_after_min -gt $wake_after_min_temp ]; then
              wake_after_min=$wake_after_min_temp
            fi
          fi
        fi
      fi
      ;;
    *)
      err "TV tuner type ${TUNER_TYPE} not found."
      ;;
    esac
     
    if [ $wake_after_min -gt 0 ]; then
      # Future event has been found.
      local wake_after_secs=$((wake_after_min*60))

      # Check safe margin shutdown.
      if [[ $SAFE_MARGIN_SHUTDOWN -gt $wake_after_secs ]]; then
        # Future event is going to happen before the computer could safely shutdown.
        is_active=1
      fi
      
      if [ -d "${RTC_FOLDER}" ]; then
        # Set RTC wake up time.
        local rtc_alarm="${RTC_FOLDER}/wakealarm"
        local stop_date=$(date +%s)
        local wake_date=$((stop_date+wake_after_secs-SAFE_MARGIN_STARTUP))
        $(echo 0 > "${rtc_alarm}")
        $(echo $wake_date > "${rtc_alarm}")
        # Check that the alarm has been set.
        if [ -f "${rtc_alarm}" ]; then
          message "Next wake up alarm set for ${wake_date}."
        else 
          message "Could not set wake up alarm for ${wake_date}."
        fi
      fi
    fi
      
    # Print a useful message depending upon the activity of the tv tuner.
    case $is_active in
    1)
      text="TV tuner is active or soon to be active."
      ;;
    *)
      text="TV tuner is not active."
      ;;
    esac
    
    message "${text}\n"
  fi
    
  # Return the TV tuner activity status.
  echo "${is_active}"
}

main() {
  # Turn script arguments into variables.
  get_options "$@"
  
  local text=""
  local total=0
  local do_shutdown=0

  total=$((total+$(check_clients "${clients}")))
  total=$((total+$(check_processes "${processes}")))
  total=$((total+$(check_sony_tvs "${sony_tvs}" "${sony_tv_auth_psk}")))
  total=$((total+$(check_users)))
  total=$((total+$(check_torrents "${torrent_type}" "${torrent_user}" "${torrent_password}" "${torrent_level}")))
  total=$((total+$(check_tv_tuner "${tv_tuner_type}" "${tv_tuner_user}" "${tv_tuner_password}" "${safe_margin_startup}" "${safe_margin_shutdown}" "${tv_tuner_epg_hours}" "${rtc_folder}")))

  case $total in
  0)
    if [ "${is_dry_run}" -eq 1 ]; then
      text="No active items found. But this is a dry run, so staying awake."
    else
      do_shutdown=1
      text="No active items found. Shutting down..."
    fi
    ;;
  *)
    text="Active items found. Staying awake."
    ;;
  esac
  
  message "${text}"

  if [ "${do_shutdown}" -eq 1 ]; then
    message "I'm really shutting down now!!!!"
    
    sleep 10s
    sudo shutdown -h now
  fi
  
  #echo "Total=${total}"
}

main "$@"
