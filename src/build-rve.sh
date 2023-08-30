#!/bin/bash
# Revanced Extended build
source ./src/tools.sh

# Check patch
check_new_patch "inotia00" "revanced-extended"

# Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"

# Download HTMLQ 
dl_htmlq

# Patch YouTube Extended
get_patches_key "youtube"
get_ver "youtube-rve"
get_apkmirror "youtube"
patch "youtube" "youtube-revanced-extended-v$version"

# Finish patch
finish_patch "revanced-extended"
