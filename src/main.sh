#!/bin/bash

dl_gh() {
    local user=$1
    local repos=$2
    local tag=$3
    if [ -z "$user" ] || [ -z "$repos" ] || [ -z "$tag" ]; then
        logger.error 'Usage: dl_gh user repo tag'
        return 1 
    fi 
    trap 'rm -f ${#downloaded_files[@]}; exit 1' INT TERM ERR
    repo in $repos; do
        logger.info "Getting asset for \"$repo\"..."
        asset_urls=$(wget -qO- "https://api.github.com/repos/$user/$repo/releases/$tag" \
                    | jq -r '.assets[] | "\(.browser_download_url) \(.name)"')        
        if [ -z "$asset_urls" ]; then
            logger.error "No assets found for $repo"
            return1
        fi        downloaded_files()
        while read -r url name; do
            logger.info "-> \"$name\" | \"$url\""
            while ! wget -q -O "$name" "$url"; do
                 sleep 1
            done
            if [ $? -ne 0 ]
            then
                logger.error "Failed to download $name from $url"
            else
                logger.success " downloaded $name from $url"
           
            downloaded_files+=("$name")
        done <<< "$asset_urls"
        if [ ${#downloaded_files[@]} -gt 0 ]; then
            logger.success "Finished download assets for \"$repo\":"
            for file in ${downloaded_files[@]}; do
                logger.info "-> \"$file\""
           
        fi
    done
    return 0
}

get_patches_key() {
    local folder="$1"
    local exclude_file="patches/${folder}/exclude-patches"
    local include_file="patches/${folder}/include-patches"
    local word
    if [ ! -d "${exclude_file%/*}" ]; then
        printf "\033[0;31mFolder not found: \"%s\"\n\033[0m" "${exclude_file%/*}"
        return 1
    fi
    if [ ! -f "$exclude_file" ]; then
        printf "\033[0;31mFile not found: \"%s\"\n\033[0m" "$exclude_file"
        return 1
    fi
    if [ ! -f "$include_file" ]; then
        printf "\033[0;31mFile not found: \"%s\"\n\033[0m" "$include_file"
        return 1
    fi
    if [ ! -r "$exclude_file" ]; then
        printf "\033[0;31mCannot read file: \"%s\"\n\033[0m" "$exclude_file"
        return 1
    fi
    if [ ! -r "$include_file" ]; then
        printf "\033[0;31mCannot read file: \"%s\"\n\033[0m" "$include_file"
        return 1
    fi
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
  eval "$(cat ./src/apkmirror.info)"
  local app_name=$1 
  local arch=$2
  if [[ -z ${apps[$app_name]} ]]; then
    printf "\033[0;31mInvalid app name\033[0m\n"
    exit 1
  fi
  local app_categories=$(echo ${apps[$app_name]} | jq -r '.category_link')
  local app_link=$(echo ${apps[$app_name]} | jq -r '.app_link')  
  if [[ -z $arch ]]; then
    printf "\033[1;33mDownloading \033[0;31m\"%s\"\033[0m\n" "$app_name"
  elif [[ $arch == "arm64-v8a" ]]; then
    printf "\033[1;33mDownloading \033[0;31m\"%s\" (arm64-v8a)\033[0m\n" "$app_name"
    url_regexp='arm64-v8a</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "armeabi-v7a" ]]; then
    printf "\033[1;33mDownloading \033[0;31m\"%s\" (armeabi-v7a)\033[0m\n" "$app_name"
    url_regexp='armeabi-v7a</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "x86" ]]; then
    printf "\033[1;33mDownloading \033[0;31m\"%s\" (x86)\033[0m\n" "$app_name"
    url_regexp='x86</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "x86_64" ]]; then
    printf "\033[1;33mDownloading \033[0;31m\"%s\" (x86_64)\033[0m\n" "$app_name"
    url_regexp='x86_64</div>[^@]*@\([^"]*\)'
  else
    printf "\033[0;31mArchitecture not exactly!!! Please check\033[0m\n"
    exit 1
  fi 
  export version=${version:-$(get_apkmirror_vers $app_categories | get_largest_ver)}
  printf "\033[1;33mChoosing version \033[0;36m'%s'\033[0m\n" "$version"
  local base_apk="$app_name.apk"
  if [[ -z $arch ]]; then
      local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
			"APK</span>[^@]*@\([^#]*\)" \
			"$base_apk")
  elif [[ $arch == "arm64-v8a" ]]; then
      local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "armeabi-v7a" ]]; then
      local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "x86" ]]; then
      local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "x86_64" ]]; then
      local dl_url=$(dl_apkmirror "$app_link-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  fi
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
    eval "$(cat ./src/uptodown.info)"
    local app_name=$1 
    if [[ -z ${apps[$app_name]} ]]; then
       printf "\033[0;31mInvalid app name\033[0m\n"
       exit 1
    fi
    local applink=$(echo ${apps[$app_name]} | jq -r '.app_link')
    printf "\033[1;33mDownloading \033[0;31m\"%s\"\033[0m\n" "$app_name"
    export version="$version"
    local out_name=$(printf '%s' "$app_name" | tr '.' '_' | tr '[:upper:]' '[:lower:]' && printf '%s' ".apk")
    local uptwod_resp
    uptwod_resp=$(get_uptodown_resp "$applink")
    local available_versions=($(get_uptodown_vers "$uptwod_resp"))
    if [[ " ${available_versions[@]} " =~ " ${version} " ]]; then
        printf "\033[1;33mChoosing version \033[0;36m'%s'\033[0m\n" "$version"
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    else
        version=${available_versions[0]}
        printf "\033[1;33mChoosing version \033[0;36m'%s'\033[0m\n" "$version"
        uptwod_resp=$(get_uptodown_resp "$applink")
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    fi
}

get_ver() {
    eval "$(cat ./src/version.info)"
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
  local apk_name=$1
  local apk_out=$2
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
  else
    printf "\033[1;33mRunning patch \033[0;31m\"%s\" \033[1;33mwith the following files:\033[0m\n" "$apk_out"
    printf "\033[0;36m->%s\033[0m\n" "$cli_jar"
    printf "\033[0;36m->%s\033[0m\n" "$integrations_apk"
    printf "\033[0;36m->%s\033[0m\n" "$patches_jar"
    printf "\033[0;36m->%s\033[0m\n" "$base_apk"
    printf "\033[0;32mINCLUDE PATCHES :%s\033[0m\n\033[0;31mEXCLUDE PATCHES :%s\033[0m\n" "${include_patches[*]}" "${exclude_patches[*]}"
    java -jar "$cli_jar" \
      --rip-lib x86 \
      --rip-lib x86_64 \
      --rip-lib armeabi-v7a \
      -m "$integrations_apk" \
      -b "$patches_jar" \
      -a "$base_apk" \
      ${exclude_patches[@]} \
      ${include_patches[@]} \
      --keystore=./src/ks.keystore \
      -o "build/$apk_out.apk"
    printf "\033[0;32mPatch \033[0;31m\"%s\" \033[0;32mis finished!\033[0m\n" "$apk_out"
  fi
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
