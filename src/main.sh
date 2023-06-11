#!/bin/bash

dl_gh() {
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

get_patches_key() {
    local folder="$1"
    local exclude_file="patches/${folder}/exclude-patches"
    local include_file="patches/${folder}/include-patches"
    local word
    for file in "$exclude_file" "$include_file"; do
        if [ ! -d "${file%/*}" ]; then
            printf "\033[0;31mFolder not found: \"%s\"\n\033[0m" "${file%/*}"
            return 1
        fi
        if [ ! -f "$file" ]; then
            printf "\033[0;31mFile not found: \"%s\"\n\033[0m" "$file"
            return 1
        fi
        if [ ! -r "$file" ]; then
            printf "\033[0;31mCannot read file: \"%s\"\n\033[0m" "$file"
            return 1
        fi
    done
    while IFS= read -r word; do
        if [[ -n "$word" ]]; then
            exclude_patches+=("-e" "$word")
        fi
    done < "$exclude_file"
    while IFS= read -r word; do
        if [[ -n "$word" ]]; then
            include_patches+=("-i" "$word")
        fi
    done < "$include_file"
    for word in "${exclude_patches[@]}"; do
        if [[ " ${include_patches[*]} " =~ " $word " ]]; then
          printf "\033[0;31mPatch \"%s\" is specified both as exclude and include\033[0m\n" "$word"
          return 1
        fi
    done
    return 0
}

req() {  
    wget -nv -O "$2" -U "Mozilla/5.0 (X11; Linux x86_64; rv:111.0) Gecko/20100101 Firefox/111.0" "$1" 
} 

get_apkmirror_vers() {  
    req "$1" - | sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p' 
} 

get_largest_ver() { 
    local max=0 
    while read -r v || [ -n "$v" ]; do                    
        if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi 
            done 
                if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi  
}

dl_apkmirror() {
    local url=$1 regexp=$2 output=$3
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n "s/href=\"/@/g; s;.*${regexp}.*;\1;p")"
    echo "$url"
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    req "$url" "$output"
}

get_apkmirror() {
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

get_uptodown_resp() {
    req "${1}/versions" -
}

get_uptodown_vers() {
    sed -n 's;.*version">\(.*\)</span>$;\1;p' <<< "$1"
}

dl_uptodown() {
    local uptwod_resp=$1 version=$2 output=$3
    local url
    url=$(grep -F "${version}</span>" -B 2 <<< "$uptwod_resp" | head -1 | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    url=$(req "$url" - | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    req "$url" "$output"
}

get_uptodown() {
     source ./src/uptodown.info
     local app_name=$1  
     if [[ -z ${apps[$app_name]} ]]; then 
        printf "\033[0;31mInvalid app name\033[0m\n" 
        exit 1 
     fi 
     local applink=$(echo ${apps[$app_name]} | jq -r '.app_link') 
     printf "\033[1;33mDownloading \033[0;31m\"%s\"\033[0m\n" "$app_name" 
     local out_name=$(printf '%s' "$app_name" | tr '.' '_' | tr '[:upper:]' '[:lower:]' && printf '%s' ".apk") 
     local uptwod_resp=$(get_uptodown_resp "$applink") 
     local available_versions=($(get_uptodown_vers "$uptwod_resp")) 
     export version=${version:-${available_versions[1]}} 
     printf "\033[1;33mChoosing version \033[0;36m'%s'\033[0m\n" "$version" 
     dl_uptodown "$uptwod_resp" "$version" "$out_name" 
}

get_ver() {
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

patch() {
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
    printf "\033[0;32mINCLUDE PATCHES :%s\033[0m\n\033[0;31mEXCLUDE PATCHES :%s\033[0m\n" "${include_patches[*]}" "${exclude_patches[*]}"
    if [[ -z "$arch" ]]; then
        shift
        java -jar "$cli_jar" \
          -m "$integrations_apk" \
          -b "$patches_jar" \
          -a "$base_apk" \
          ${exclude_patches[@]} \
          ${include_patches[@]} \
          --keystore=./src/ks.keystore \
          -o "build/$apk_out.apk"
    else
        if [[ ! ${arch_map[$arch]+_} ]]; then
            printf "\033[0;31mError: invalid arch value\033[0m\n"
            exit 1
        else
            java -jar "$cli_jar" \
              -m "$integrations_apk" \
              -b "$patches_jar" \
              -a "$base_apk" \
              ${exclude_patches[@]} \
              ${include_patches[@]} \
              ${arch_map[$arch]} \
              --keystore=./src/ks.keystore \
              -o "build/$apk_out.apk"
        fi
    fi
    printf "\033[0;32mPatch \033[0;31m\"%s\" \033[0;32mis finished!\033[0m\n" "$apk_out"
    vars_to_unset=(
        "version"
        "exclude_patches"
        "include_patches"
    )
    for varname in "${vars_to_unset[@]}"; do
        if [[ -v "$varname" ]]; then
            unset "$varname"
        fi
    done
    rm -f ./"$base_apk"
}