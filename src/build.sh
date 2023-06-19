
#!/bin/bash
# Revanced Extended build
source ./src/main.sh

check_new_patch "inotia00" "revanced-extended"

#Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"

# Patch YouTube Extended
get_patches_key "youtube"
get_ver "youtube-rve"
get_apkmirror "youtube"
#get_uptodown "youtube"
patch "youtube" "yt-rve-v$version" "arm64-v8a"

# Patch YouTube Music Extended 
get_patches_key "ytmusic"
version="6.04.53"
get_apkmirror "youtube-music" "arm64-v8a"
#get_uptodown "youtube-music"
patch "youtube-music" "yt-music-v$version" "arm64-v8a"

ls revanced-patches*.jar >> revanced-extended-version.txt
for file in ./*.jar ./*.apk ./*.json
   do rm -f "$file"
done
