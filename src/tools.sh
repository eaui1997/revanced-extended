#!/bin/bash

function check_new_patch() {
    local user=$1
    local txt_name=$2
    release=$(wget -qO- "https://api.github.com/repos/$user/revanced-patches/releases/latest")
    asset=$(echo "$release" | jq -r '.assets[] | select(.name | test("revanced-patches.*\\.jar$")) | .browser_download_url')
    wget -q "$asset"
    ls revanced-patches*.jar >> new.txt
    rm -f revanced-patches*.jar
    release=$(wget -qO- "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest")
    asset=$(echo "$release" | jq -r '.assets[] | select(.name == "'$txt_name'-version.txt") | .browser_download_url')
    wget -q "$asset"
    if diff -q $txt_name-version.txt new.txt >/dev/null
        then
            rm -f ./*.txt
            printf "\033[0;31mOld patch!!! Not build\033[0m\n"
            exit 0
        else
            printf "\033[0;32mBuild...\033[0m\n"
            rm -f ./*.txt
     fi
}

function dl_gh() {
    local user=$1
    local repos=$2
    local tag=$3
    if [ -z "$user" ] || [ -z "$repos" ] || [ -z "$tag" ]; then
        printf '%b\n' '\033[0;31mUsage: dl_gh user repo tag\033[0m' 
        return 1 
    fi 
    trap 'rm -f ${#downloaded_files[@]}; exit 1' INT TERM ERR
    for repo in $repos; do
        printf "\033[1;33mGetting asset URLs for \"%s\"...\033[0m\n" "$repo"
        asset_urls=$(wget -qO- "https://api.github.com/repos/$user/$repo/releases/$tag" \
                    | jq -r '.assets[] | "\(.browser_download_url) \(.name)"')        
        if [ -z "$asset_urls" ]; then
            printf "\033[0;31mNo assets found for %s\033[0m\n" "$repo"
            return 1
        fi     
        downloaded_files=()
        while read -r url name; do
            printf "\033[0;34m-> \033[0;36m\"%s\"\033[0;34m | \033[0;36m\"%s\"\033[0m\n" "$name" "$url"
            while ! wget -q -O "$name" "$url"; do
                sleep 1
            done
            printf "\033[0;32m-> \033[0;36m\"%s\"\033[0m [\033[0;32m\"$(date +%T)\"\033[0m] [\033[0;32mDONE\033[0m]\n" "$name"
            downloaded_files+=("$name")
        done <<< "$asset_urls"
        if [ ${#downloaded_files[@]} -gt 0 ]; then
            printf "\033[0;32mFinished download assets for \033[1;33m\"%s\":\033[0m\n" "$repo"
            for file in ${downloaded_files[@]}; do
                printf " -> \033[0;34m\"%s\"\033[0m\n" "$file"
            done
        fi
    done
    return 0
}

function get_patches_key() {
    local patch_file="$1"
    patch_content=($(cat patches/$patch_file))
    exclude_string=()
    include_string=()
    exclude_patches=""
    include_patches=""
    flag=""
    for line in "${patch_content[@]}"; do
        if [[ $line == --exclude* ]]; then
            flag="exclude"
            exclude_string+=(${line#--exclude})
        elif [[ $line == --include* ]]; then
            flag="include"
            include_string+=(${line#--include})
        elif [[ -n $line && $line != --* ]]; then
            if [[ $flag == "exclude" ]]; then
                exclude_string+=($line)
            elif [[ $flag == "include" ]]; then
                include_string+=($line)
            fi
        fi
    done
    for patch in "${exclude_string[@]}" ; do
        exclude_patches+="--exclude $patch "
        if [[ " ${include_string[@]} " =~ " $patch " ]]; then
            printf "\033[0;31mPatch \"%s\" is specified both as exclude and include\033[0m\n" "$patch"
            return 1
        fi
    done
    for patch in "${include_string[@]}" ; do
        include_patches+="--include $patch "
    done
    return 0
}

function dl_htmlq() {
    req "https://github.com/mgdm/htmlq/releases/latest/download/htmlq-x86_64-linux.tar.gz" "./htmlq.tar.gz"
    tar -xf "./htmlq.tar.gz" -C "./"
    rm "./htmlq.tar.gz"
    HTMLQ="./htmlq"
}

function _req() {
    if [ "$2" = - ]; then
	wget -nv -O "$2" --header="$3" "$1"
    else
	local dlp
	dlp="$(dirname "$2")/$(basename "$2")"
	if [ -f "$dlp" ]; then
		while [ -f "$dlp" ]; do sleep 1; done
		return
	fi
	wget -nv -O "$dlp" --header="$3" "$1" || return 1
    fi
}
function req() { 
    _req "$1" "$2" "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0"
}

function get_apkmirror_vers() {  
    req "$1" - | sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p' 
} 

function get_largest_ver() { 
    local max=0 
    while read -r v || [ -n "$v" ]; do                    
        if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi 
            done 
                if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi  
}

function dl_apkmirror() {
    local url=$1 regexp=$2 output=$3 resp
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n "s/href=\"/@/g; s;.*${regexp}.*;\1;p")"
    echo "$url"
    url=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "a.accent_bg.btn")
    resp=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "span > a[rel = nofollow]")
    if [[ -z $resp ]]; then
	url=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "a.accent_bg.btn")
	url=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "span > a[rel = nofollow]")
    else
	url=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "span > a[rel = nofollow]")
    fi
    req "$url" "$output"
}

function get_apkmirror() {
    source ./src/apkmirror.info
    source ./src/arch_regexp.info
    local app_name=$1 
    local arch=$2
    if [[ -z ${apps[$app_name]} ]]; then
        printf "\033[0;31mInvalid app name\033[0m\n"
        exit 1
    fi
    local app_category=$(echo ${apps[$app_name]} | jq -r '.category_link')
    local app_link=$(echo ${apps[$app_name]} | jq -r '.app_link')  
    printf "\033[1;33mDownloading \033[0;31m\"%s\"" "$app_name"
    if [[ -n $arch ]]; then
        printf " (%s)" "$arch"
    fi
    printf "\033[0m\n"
    if [[ -z $arch ]]; then
        arch="universal"
    fi
    if [[ -z ${url_regexp_map[$arch]} ]]; then
        printf "\033[0;31mArchitecture not exactly!!! Please check\033[0m\n"
        exit 1
    fi 
    export version=${version:-$(get_apkmirror_vers $app_category | get_largest_ver)}
    printf "\033[1;33mChoosing version \033[0;36m'%s'\033[0m\n" "$version"
    local base_apk="$app_name.apk"
    local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
                                "${url_regexp_map[$arch]}" \
                                "$base_apk")
}

function get_ver() {
    source ./src/versions.info
    local app_name=$1 
    local patch_name=$(echo ${versions[$app_name]} | jq -r '.patch')
    local pkg_name=$(echo ${versions[$app_name]} | jq -r '.package')
    if [[ ! -f patches.json ]]; then
       printf "\033[0;31mError: patches.json file not found.\033[0m\n"
       return 1
     else
       export version=$(jq -r --arg patch_name "$patch_name" --arg pkg_name "$pkg_name" '
       .[]
       | select(.name == $patch_name)
       | .compatiblePackages[]
       | select(.name == $pkg_name)
       | .versions[-1]
       ' patches.json)
      if [[ -z $version ]]; then
         printf "\033[0;31mError: Unable to find a compatible version.\033[0m\n"
         return 1
      fi
    fi
    return 0
}

function patch() {
    source ./src/--rip-lib.info
    local apk_name=$1
    local apk_out=$2
    local arch=$3
    printf "\033[1;33mStarting patch \033[0;31m\"%s\"\033[1;33m...\033[0m\n" "$apk_out"
    local base_apk=$(find -name "$apk_name.apk" -print -quit)
    if [[ ! -f "$base_apk" ]]; then
        printf "\033[0;31mError: APK file not found\033[0m\n"
        exit 1
    fi
    printf "\033[1;33mSearching for patch files...\033[0m\n"
    local patches_jar=$(find -name "revanced-patches*.jar" -print -quit)
    local integrations_apk=$(find -name "revanced-integrations*.apk" -print -quit)
    local cli_jar=$(find -name "revanced-cli*.jar" -print -quit)
    if [[ -z "$patches_jar" ]] || [[ -z "$integrations_apk" ]] || [[ -z "$cli_jar" ]]; then
        printf "\033[0;31mError: patches files not found\033[0m\n"
        exit 1
    fi
    printf "\033[1;33mRunning patch \033[0;31m\"%s\" \033[1;33mwith the following files:\033[0m\n" "$apk_out"
    for file in "$cli_jar" "$integrations_apk" "$patches_jar" "$base_apk"; do
        printf "\033[0;36m->%s\033[0m\n" "$file"
    done
    printf "\033[0;32mINCLUDE PATCHES :%s\033[0m\n\033[0;31mEXCLUDE PATCHES :%s\033[0m\n" "${include_string[*]}" "${exclude_string[*]}"
    if [[ -z "$arch" ]]; then
        shift
        java -jar "$cli_jar" \
             --apk "$base_apk" \
             --bundle "$patches_jar" \
             --merge "$integrations_apk" \
             ${exclude_patches} \
             ${include_patches} \
             --keystore ./src/ks.keystore \
             --out "build/$apk_out.apk"
    else
        if [[ ! ${arch_map[$arch]+_} ]]; then
            printf "\033[0;31mError: invalid split arch value\033[0m\n"
            exit 1
        else
            java -jar "$cli_jar" \
                 --apk "$base_apk" \
                 --bundle "$patches_jar" \
                 --merge "$integrations_apk" \
                 ${exclude_patches} \
                 ${include_patches} \
                 ${arch_map[$arch]} \
                 --keystore ./src/ks.keystore \
                 --out "build/$apk_out-$arch.apk"
        fi
    fi
    printf "\033[0;32mPatch \033[0;31m\"%s\" \033[0;32mis finished!\033[0m\n" "$apk_out"
    vars_to_unset=("version" "exclude_patches" "include_patches" "exclude_string" "include_string")
    for varname in "${vars_to_unset[@]}"; do
        if [[ -v "$varname" ]]; then
            unset "$varname"
        fi
    done
    rm -f ./"$base_apk"
}

function finish_patch() {
    local txt_name=$1
    ls revanced-patches*.jar >> $txt_name-version.txt
    for file in ./*.jar ./*.apk ./*.json
        do rm -f "$file"
    done
}

function split_apk() {
    source ./src/--rip-lib.info
    local apk_name=$1
    local base_apk=$(find -name "$apk_name*.apk" -print -quit)
    if [[ ! -f "$base_apk" ]]; then
        printf "\033[0;31mError: APK file not found\033[0m\n"
        exit 0
    fi
    local patches_jar=$(find -name "revanced-patches*.jar" -print -quit)
    local cli_jar=$(find -name "revanced-cli*.jar" -print -quit)
    if [[ -z "$patches_jar" ]] || [[ -z "$cli_jar" ]]; then
        printf "\033[0;31mError: patches files not found\033[0m\n"
        exit 0
    fi
    archs=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")
    for arch in "${archs[@]}"; do
        printf "\033[0;33mSplitting \033[0;31m\"%s\" \033[0;33m to \033[0;31m\"%s\" \033[0;33m\n" "$apk_name" "$apk_name-$arch"
        java -jar "$cli_jar" \
             --apk "$base_apk" \
             --bundle "$patches_jar" \
             ${arch_map[$arch]} \
             --keystore ./src/ks.keystore \
             --out "build/$apk_name-$arch.apk"
        printf "\033[0;32mSplit \033[0;31m\"%s\" \033[0;32m is finished.\033[0m\n" "$apk_name-$arch"
    done
}
