# sleep

Bash script to shutdown a computer if certain criteria are met:-
  - None of the listed clients are active.
  - None of the listed processes are active.
  - None of the listed Sony TVs are active.
  - No users logged-on.
  - No torrents are active, such as downloading or seeding.
  - No TV tuner is active, such as recording or streaming.

## Usage

```bash
sleep.sh
```
This would shutdown a computer if no users are logged-on, and no `cp`, `mv`, `rsync` or `scp` processses are running. 

```bash
sleep.sh --clients "192.168.1.12 192.168.1.34"
```
This would shutdown a computer if `192.168.1.12` and `192.168.1.34` are not reachable on the network, no users are logged-on, and no `cp`, `mv`, `rsync` or `scp` processses are running. 

```bash
sleep.sh --torrent-level "active_downloads" --torrent-type "transmission" --torrent-password "my_torrent_password"
```
This would shutdown a computer if `transmission` is not actively downloading anything, no users are logged-on, and no `cp`, `mv`, `rsync` or `scp` processses are running. 

```bash
sleep.sh --sony-tvs "192.168.1.67 192.168.1.89" --sony-tv-auth-psk "my_sony_psk"
```
This would shutdown a computer if the Sony Tv's `192.168.1.67` and `192.168.1.89` are not active, no users are logged-on, and no `cp`, `mv`, `rsync` or `scp` processses are running. 

## Options

#### Clients `--clients `

A shutdown will only occur if the specified clients are not reachable on the network. A space-seperated list of IP addresses.

#### Dry run `-n `

Perform a trial run with **no shutdown** being implemented. Verbose output will be shown printed to the terminal.

#### Processes `--processes `

A shutdown will only occur if the specified processes are not running. A space-seperated list. Default value is `cp mv rsync scp`.

#### RTC folder `--rtc-folder `

Location of wake-up alarm. If a TV tuner is detected, and a future recording date has been found, an alarm will be set to the specified RTC folder. Default value is `/sys/class/rtc/rtc0`.

#### Safe margin shutdown `--safe-margin-shutdown `

Minimum time in seconds needed for consecutive shutdown AND startup. Default value is `600`.

#### Safe margin start-up `--safe-margin-startup `

Minimum time in seconds needed to start-up the computer properly. Default value is `180`.

#### Sony TV pre-shared key (PSK) `--sony-tv-auth-psk `

The password to be used when using the Sony TV API.

#### Sony TVs `--sony-tvs `

A shutdown will only occur if the specified Sony TVs are not active. A space-seperated list of IP addresses.

#### Torrent type `--torrent-type `

The type of the torrent client. Currently only supports `transmission`.

#### Torrent level `--torrent-level `

A shutdown will only occur if their are no torrents in the specified range. Currently only supports `active` and `active_downloads`.
  - `active` - includes torrents being downloaded and seeded.
  - `active_downloads` - only includes torrents being downloaded. 

#### Torrent user `--torrent-user `

The username for the specified torrent client.

#### Torrent password `--torrent-password `

The password for the specified torrent client.

#### TV tuner type `--tv-tuner-type `

The type of the TV tuner. Currently only supports `tvheadend`.

#### TV tuner user `--tv-tuner-user `

The username for the specified TV tuner.

#### TV tuner password `--tv-tuner-password `

The password for the specified TV tuner.

#### TV tuner EPG hours `--tv-tuner-epg-hours `

Maximum time in hours not to wake up for updating EPG.

#### Verbose `-v `

Increase the amount of information printed to the terminal.