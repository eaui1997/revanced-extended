#!/bin/bash
# Revanced Extended build
source ./src/tools.sh

# Check patch
check_new_patch "inotia00" "revanced-extended"

# Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"
dl_htmlq

# Patch YouTube Extended
get_patches_key "youtube"
get_ver "youtube-rve"
get_apkmirror "youtube"
#get_uptodown "youtube"
patch "youtube" "youtube-revanced-extended-v$version"

# Patch YouTube Music Extended 
get_patches_key "ytmusic"
get_apkmirror "youtube-music" "arm64-v8a"
#get_uptodown "youtube-music"
patch "youtube-music" "youtube-music-revanced-extended-v$version" "arm64-v8a"

#Reddit
get_patches_key "reddit"
get_apkmirror "reddit"
#get_uptodown "reddit"
patch "reddit" "reddit-revanced-extended-v$version"

# Finish patch
finish_patch "revanced-extended"

# Split APK
dl_gh "inotia00" "revanced-patches revanced-cli" "latest"
split_apk "youtube-revanced-extended"
