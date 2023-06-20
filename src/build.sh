
#!/bin/bash
# Revanced Extended build
source ./src/main.sh

# Check patch
check_new_patch "inotia00" "revanced-extended"

# Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"

# Patch YouTube Extended
get_patches_key "youtube"
get_ver "youtube-rve"
get_apkmirror "youtube"
#get_uptodown "youtube"
patch "youtube" "youtube-revanced-extended"

# Patch YouTube Music Extended 
get_patches_key "ytmusic"
version="6.04.53"
#get_apkmirror "youtube-music" "arm64-v8a"
get_uptodown "youtube-music"
patch "youtube-music" "youtube-music-revanced-extended"

# Finish patch
finish_patch "revanced-extended"

# Split APK
dl_gh "j-hc" "revanced-cli" "latest"
dl_gh "inotia00" "revanced-patches" "latest"
split_apk "youtube-revanced-extended"
