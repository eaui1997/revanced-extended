
#!/bin/bash
# Revanced Extended build
source ./src/main.sh

release=$(curl -sL "https://api.github.com/repos/inotia00/revanced-patches/releases/latest")
asset=$(echo "$release" | jq -r '.assets[] | select(.name | test("revanced-patches.*\\.jar$")) | .browser_download_url')
curl -sLO "$asset"

ls revanced-patches*.jar >> new.txt
rm -f revanced-patches*.jar

release=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest")
asset=$(echo "$release" | jq -r '.assets[] | select(.name == "revanced-extended-version.txt") | .browser_download_url')
curl -sLO "$asset"

if diff -q revanced-extended-version.txt new.txt >/dev/null ; then
rm -f ./*.txt
printf "\033[0;31mOld patch!!! Not build\033[0m\n"
exit 0
else
printf "\033[0;32mBuild...\033[0m\n"
rm -f ./*.txt

#Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"

# Patch YouTube Extended
get_patches_key "youtube"
get_ver "hide-general-ads" "com.google.android.youtube"
#get_apkmirror "youtube"
get_uptodown "youtube"
patch "youtube" "yt-rve-v$version"

# Patch YouTube Music Extended 
get_patches_key "ytmusic"
#get_apkmirror "youtube-music" "arm64-v8a"
get_uptodown "youtube-music"
patch "youtube-music" "yt-music-v$version"

ls revanced-patches*.jar >> revanced-extended-version.txt
for file in ./*.jar ./*.apk ./*.json
   do rm -f "$file"
done
fi
