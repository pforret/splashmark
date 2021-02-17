#!/usr/bin/env bash
### Created by Peter Forret ( pforret ) on 2020-09-28
script_version="0.0.0" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_created="2020-09-28"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

list_options() {
  force=0
  echo -n "
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
option|l|log_dir|folder for debug files |$HOME/log/$script_prefix
option|t|tmp_dir|folder for temp files|.tmp
option|1|northwest|text to put in left top|
option|2|northeast|text to put in right top|{url}
option|3|southwest|text to put in left bottom|Created with pforret/splashmark
option|4|southeast|text to put in right bottom|{copyright2}
option|w|width|image width for resizing|1200
option|c|crop|image height for cropping|0
option|e|effect|use effect chain on image: bw/blur/dark/grain/light/median/paint/pixel|
option|g|gravity|title alignment left/center/right|center
option|m|margin|margin for watermarks|30
option|i|title|big text to put in center|
option|z|titlesize|font size for title|80
option|k|subtitle|big text to put in center|
option|j|subtitlesize|font size for subtitle|50
option|o|fontsize|font size for watermarks|15
option|p|fonttype|font type family to use|FiraSansExtraCondensed-Bold.ttf
option|r|fontcolor|font color to use|FFFFFF
option|x|photographer|photographer name (empty: get from Unsplash)|
option|u|url|photo URL override (empty: get from Unsplash)|
option|d|randomize|take a random picture in the first N results|1
option|U|UNSPLASH_ACCESSKEY|Unsplash access key|
param|1|action|action to perform: download/search/file/url
param|?|output|output file
param|?|input|URL or search term
" | grep -v '^#'
}

list_dependencies() {
  ### Change the next lines to reflect which binaries(programs) or scripts are necessary to run this script
  # Example 1: a regular package that should be installed with apt/brew/yum/...
  #curl
  # Example 2: a program that should be installed with apt/brew/yum/... through a package with a different name
  #convert|imagemagick
  # Example 3: a package with its own package manager: basher (shell), go get (golang), cargo (Rust)...
  #progressbar|basher install pforret/progressbar
  echo -n "
curl
exiftool
convert|imagemagick
mogrify|imagemagick
" | grep -v "^#" | grep -v '^\s*$'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  require_binaries
  log_to_file "[$script_basename] $script_version started"

  action=$(lower_case "$action")
  case $action in
  download|d|unsplash)
    #TIP: use «splashmark download» to download a specific Unsplash photo and work with it (requires free Unsplash API key)
    #TIP:> splashmark download splash.jpg "https://unsplash.com/photos/xWOTojs1eg4"
    #TIP:> splashmark -i "The Title" -k "The subtitle" download output.jpg "https://unsplash.com/photos/xWOTojs1eg4"
    #TIP:> splashmark -i "Splash" -k "Subtitle" -w 1280 -c 640 -e dark,grain download output.jpg "https://unsplash.com/photos/xWOTojs1eg4"
    if [[ -z "${UNSPLASH_ACCESSKEY:-}" ]] ; then
      die "You need valid Unsplash API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
    fi
    image_source="unsplash"
    # shellcheck disable=SC2154
    photo_id=$(basename "$input")
    if [[ -n "$photo_id" ]]; then
      debug "Found photo ID = $photo_id"
      image_file=$(download_image_from_unsplash "$photo_id")
      get_metadata_from_unsplash "$photo_id"
      # shellcheck disable=SC2154
      image_modify "$image_file" "$output"
      out "$output"
    fi
    ;;

  search|s)
    #TIP: use «splashmark search» to search for a keyword on Unsplash and take the Nth photo (requires free Unsplash API key)
    #TIP:> splashmark search waterfall.jpg waterfall
    #TIP:> splashmark --randomize --title "Splash" --subtitle "Subtitle" --width  1280 --crop 640 --effect dark,grain search waterfall.jpg waterfall
    if [[ -z "${UNSPLASH_ACCESSKEY:-}" ]] ; then
      die "You need valid Unsplash API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
    fi
    image_source="unsplash"
    photo_id=$(search_from_unsplash "$input")
    if [[ -n "$photo_id" ]]; then
      debug "Found photo ID = $photo_id"
      image_file=$(download_image_from_unsplash "$photo_id")
      get_metadata_from_unsplash "$photo_id"
      image_modify "$image_file" "$output"
      out "$output"
    fi
    ;;

  file|f)
    #TIP: use «splashmark file» to add texts and effects to a existing image
    #TIP:> splashmark file waterfall.jpg sources/original.jpg
    #TIP:> splashmark --title "Strawberry" -w 1280 -c 640 -e dark,median,grain file waterfall.jpg sources/original.jpg
    image_source="file"
    [[ ! -f "$input" ]] && die "Cannot find input file [$input]"
    image_modify "$input" "$output"
    out "$output"
    ;;

  url|u)
    #TIP: use «splashmark url» to add texts and effects to a image that will be downloaded from a URL
    #TIP:> splashmark file waterfall.jpg "https://i.imgur.com/rbXZcVH.jpg"
    #TIP:> splashmark -w 1280 -c 640 -4 "Photographer: John Doe" -e dark,median,grain url waterfall.jpg "https://i.imgur.com/rbXZcVH.jpg"
    image_source="url"
    image_file=$(download_image_from_url "$input")
    [[ ! -f "$image_file" ]] && die "Cannot download input image [$input]"
    image_modify "$image_file" "$output"
    out "$output"
    ;;

  check|env)
    ## leave this default action, it will make it easier to test your script
    #TIP: use «$script_prefix check» to check if this script is ready to execute and what values the options/flags are
    #TIP:> $script_prefix check
    #TIP: use «$script_prefix env» to generate an example .env file
    #TIP:> $script_prefix env > .env
    check_script_settings
    ;;

  *)
    die "action [$action] not recognized"
    ;;
  esac
}

#TIP: to create a social image for Github
#TIP:> splashmark -w 1280 -c 640 -z 100 -i "<user>/<repo>" -k "line 1\nline 2" -r EEEEEE -e median,dark,grain search search <repo>.jpg <keyword>
#TIP: to create a social image for Instagram
#TIP:> splashmark -w 1080 -c 1080 -z 150 -i "Carpe diem" -e dark search instagram.jpg clouds
#TIP: to create a social image for Facebook
#TIP:> splashmark -w 1200 -c 630 -i "20 worldwide destinations\nwith the best beaches\nfor unforgettable holidays" -e dark search facebook.jpg copacabana

#####################################################################
## Put your helper scripts here
#####################################################################

unsplash_api() {
  # $1 = relative API URL
  # $2 = jq query path
  local uniq
  local api_endpoint="https://api.unsplash.com"
  local full_url="$api_endpoint$1"
  local show_url="$api_endpoint$1"
  if [[ $full_url =~ "?" ]]; then
    # already has querystring
    full_url="$full_url&client_id=$UNSPLASH_ACCESSKEY"
  else
    # no querystring yet
    full_url="$full_url?client_id=$UNSPLASH_ACCESSKEY"
  fi
  uniq=$(echo "$full_url" | hash 8)
  # shellcheck disable=SC2154
  local cached="$tmp_dir/unsplash.$uniq.json"
  if [[ ! -f "$cached" ]] ; then
    # only get the data once
    debug "API = [$show_url]"
    curl -s "$full_url" > "$cached"
    if [[ $(< "$cached" wc -c) -lt 10 ]] ; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
      return 1
    fi
    if grep -q "Rate Limit Exceeded" "$cached" ; then
      # remove if response is API throttling starts
      rm "$cached"
      alert "API call to [$1] was throttled - remember it's limited to 50 req/hr!"
      return 2
    fi
  else
    debug "API = [$cached]"
  fi
  < "$cached" jq "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

get_metadata_from_unsplash() {
  # only get metadata if it was not yet specified as an option
  [[ -z "${photographer:-}" ]]  && photographer=$(unsplash_api "/photos/$1" ".user.name")
  [[ -z "${url:-}" ]] && url=$(unsplash_api "/photos/$1" ".links.html")
}

download_image_from_unsplash() {
  # $1 = photo_id
  # returns path of downloaded file
  photo_id=$(basename "/a/$1") # to avoid problems with image ID that start with '-'
  image_url=$(unsplash_api "/photos/$photo_id" .urls.regular)
  cached_image="$tmp_dir/$photo_id.jpg"
  if [[ ! -f "$cached_image" ]]; then
    debug "IMG = [$image_url]"
    curl -s -o "$cached_image" "$image_url"
  else
    debug "IMG = [$cached_image]"
  fi
  [[ ! -f "$cached_image" ]] && die "download [$image_url] failed"
  echo "$cached_image"
}

download_image_from_url(){
  # $1 = url
  local uniq
  local extension="jpg"
  [[ "$1" =~ .png ]] && extension="png"
  [[ "$1" =~ .gif ]] && extension="gif"
  uniq=$(echo "$1" | hash 8)
  cached_image="$tmp_dir/image.$uniq.$extension"
  if [[ ! -f "$cached_image" ]] ; then
    debug "IMG = [$1]"
    curl -s -o "$cached_image" "$1"
  else
    debug "IMG = [$cached_image]"
  fi
  echo "$cached_image"
}

search_from_unsplash() {
  # $1 = keyword(s)
  # returns first result
  # shellcheck disable=SC2154
  if [[ "$randomize" == 1 ]] ; then
    unsplash_api "/search/photos/?query=$1" ".results[0].id"
  else
    choose_from=$(unsplash_api "/search/photos/?query=$1" .results[].id | wc -l)
    debug "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    debug "PICK: photo $chosen from first $choose_from results"
    unsplash_api "/search/photos/?query=$1" ".results[$chosen].id"
  fi
}

set_exif() {
  filename="$1"
  exif_key="$2"
  exif_val="$3"

  if [[ -n "$exif_val" ]]; then
    debug "EXIF: set [$exif_key] to [$exif_val] for [$filename]"
    exiftool -overwrite_original -"$exif_key"="$exif_val" "$filename" >/dev/null 2>/dev/null
  fi
}

set_metadata_tags() {
  # $1 = type
  # $2 = filename
  # https://exiftool.org/TagNames/index.html
  #  ExifTool Version Number         : 10.10
  #  Artist                          : Artist
  #  By-line                         : Author
  #  By-line Title                   : Author Title
  #  Caption-Abstract                : Caption
  #  Category                        : Category
  #  City                            : City
  #  Copyright Notice                : Copyright
  #  Country-Primary Location Name   : Country
  #  Creator                         : Creator
  #  Credit                          : Credit
  #  Date Created                    : 2020:10:18
  #  File Name                       : metadata.jpg
  #  Headline                        : Headline
  #  ImageDescription                : ImageDescription
  #  Keywords                        : Keywords
  #  Object Name                     : Document Title
  #  Original Transmission Reference : Reference
  #  Owner ID                        : OwnerID
  #  Owner Name                      : OwnerName
  #  Source                          : Source
  #  Special Instructions            : Instructions
  #  Sub-location                    : Sub-location
  #  Supplemental Categories         : OtherCategories
  #  Urgency                         : 1 (most urgent)
  #  Writer-Editor                   : Caption Writer
  set_exif "$2" "Writer-Editor" "https://github.com/pforret/splashmark"
  if [[ "$1" == "unsplash" ]] ; then
    ## metadata comes from Unsplash
    if [[ -f "$2" && -n ${photographer} ]]; then
      set_exif "$2" "Artist" "$photographer"
      set_exif "$2" "Creator" "$photographer"
      set_exif "$2" "OwnerID" "$photographer"
      set_exif "$2" "OwnerName" "$photographer"
      set_exif "$2" "Credit" "Photo: $photographer on Unsplash.com"
      set_exif "$2" "ImageDescription" "Photo: $photographer on Unsplash.com"
    fi
  else
    ## metadata, if any, comes from command line options
    if [[ -f "$2" && -n ${photographer} ]]; then
      set_exif "$2" "Artist" "$photographer"
      set_exif "$2" "Creator" "$photographer"
      set_exif "$2" "OwnerID" "$photographer"
      set_exif "$2" "OwnerName" "$photographer"
      set_exif "$2" "ImageDescription" "Photo: $photographer"
    fi
  fi
}

image_modify() {
  # $1 = input file
  # $2 = output file

  font_list="$tmp_dir/magick.fonts.txt"
  if [[ ! -f "$font_list" ]] ; then
    convert -list font | awk -F: '/Font/ {gsub(" ","",$2); print $2 }' > "$font_list"
  fi
  if [[ -f "$fonttype" ]] ; then
    debug "FONT [$fonttype] exists as a font file"
  elif grep -q "$fonttype" "$font_list" ; then
    debug "FONT [$fonttype] exists as a standard font"
  elif [[ -f "$script_install_folder/fonts/$fonttype" ]] ; then
    fonttype="$script_install_folder/fonts/$fonttype"
    debug "FONT [$fonttype] exists as a splashmark font"
  else
    die "FONT [$fonttype] cannot be found on this system"
  fi
  [[ ! -f "$1" ]] && return 1

  ## scale and crop
  # shellcheck disable=SC2154
  if [[ $crop -gt 0 ]]; then
    debug "CROP: image to $width x $crop --> $2"
    convert "$1" -gravity Center -resize "${width}x${crop}^" -crop "${width}x${crop}+0+0" +repage -quality 95% "$2"
  else
    debug "SIZE: to $width wide --> $2"
    convert "$1" -gravity Center -resize "${width}"x -quality 95%  "$2"
  fi
  ## set EXIF/IPTC tags
  set_metadata_tags "$image_source" "$2"

  ## do visual effects
  # shellcheck disable=SC2154
  if [[ -n "$effect" ]] ; then
    image_effect "$2" "$effect"
  fi
  ## add small watermarks in the corners
  # shellcheck disable=SC2154
  [[ -n "$northwest" ]] && image_watermark "$2" NorthWest "$northwest"
  # shellcheck disable=SC2154
  [[ -n "$northeast" ]] && image_watermark "$2" NorthEast "$northeast"
  # shellcheck disable=SC2154
  [[ -n "$southwest" ]] && image_watermark "$2" SouthWest "$southwest"
  # shellcheck disable=SC2154
  [[ -n "$southeast" ]] && image_watermark "$2" SouthEast "$southeast"

  ## add large title watermarks in the middle
  # shellcheck disable=SC2154
  [[ -n "$title" || -n "$subtitle" ]] && image_title "$2"
}

text_resolve() {
  case $image_source in
  unsplash)
    echo "$1" \
    | sed "s|{copyright}|Photo by {photographer} on Unsplash.com|" \
    | sed "s|{copyright2}|© {photographer} » Unsplash.com|" \
    | sed "s|{photographer}|$photographer|" \
    | sed "s|{url}|$url|" \
    | sed "s|https://||"
    ;;
    *)
    echo "$1" \
    | sed "s|{copyright}| |" \
    | sed "s|{copyright2}| |" \
    | sed "s|{photographer}| |" \
    | sed "s|{url}| |" \
    | sed "s|https://||"
  esac
}

image_effect(){
  # $1 = image path
  # $2 = effect name
  # shellcheck disable=SC2154
  [[ ! -f "$1" ]] && return 1

  for fx1 in $(echo "$effect" | tr ',' "\n") ; do
    debug "EFX : $fx1"
    case "$fx1" in
    blur)             mogrify -blur 5x5 "$1"  ;;
    dark|darken)      mogrify -fill black -colorize 25% "$1" ;;
    grain)            mogrify -attenuate .95 +noise Gaussian "$1" ;;
    light|lighten)    mogrify -fill white -colorize 25% "$1"  ;;
    median)           mogrify -median 5 "$1"  ;;
    monochrome|bw)    mogrify -modulate 100,1 "$1"  ;;
    norm|normalize)   mogrify -normalize "$1" ;;
    paint)            mogrify -paint 5  "$1"  ;;
    pixel)            mogrify -resize 10% -scale 1000%  "$1"  ;;
    sketch)           mogrify -sketch 5x5+45  "$1"  ;;
    *)
      # shellcheck disable=SC2086
      eval mogrify $effect "$1"
    esac
  done
}

image_watermark() {
  # $1 = image path
  # $2 = gravity
  # $3 = text

  [[ ! -f "$1" ]] && return 1
  # shellcheck disable=SC2154
  char1=$(upper_case "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008" ;;
  *)
    shadow_color="FFF8" ;;
  esac
  text=$(text_resolve "$3")

  debug "MARK: [$text] in $2 corner ..."
  # shellcheck disable=SC2154
  margin2=$((margin + 1))
  # shellcheck disable=SC2154
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$fontcolor"    -annotate "0x0+${margin}+${margin}"   "$text" "$1"
}

choose_position(){
  position="$1"
  # shellcheck disable=SC2154
  case $(lower_case "$gravity") in
    left|west)  position="${position}West" ;;
    right|east) position="${position}East" ;;
  esac
  [[ -z "$position" ]] && position="Center"
  echo "$position"
}

image_title() {
  # $1 = image path

  [[ ! -f "$1" ]] && return 1
  # shellcheck disable=SC2154
  char1=$(upper_case "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008" ;;
  *)
    shadow_color="FFF8" ;;
  esac
  margin1=$((margin * 3))
  margin2=$((margin1 + 1))
  if [[ -n "$title" ]] ; then
    text=$(text_resolve "$title")
    position=""
    [[ -n "$subtitle" ]] && position="North"
    position=$(choose_position "$position")
    debug "MARK: title [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(lower_case "$gravity") == "center" ]] ; then
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$shadow_color" -annotate "0x0+1+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$fontcolor"    -annotate "0x0+0+${margin1}"  "$text" "$1"
    else
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$fontcolor"    -annotate "0x0+${margin1}+${margin1}"   "$text" "$1"
    fi
  fi
  if [[ -n "$subtitle" ]] ; then
    text=$(text_resolve "$subtitle")
    position=""
    [[ -n "$title" ]] && position="South"
    position=$(choose_position "$position")
    debug "MARK: subtitle [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(lower_case "$gravity") == "center" ]] ; then
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+1+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor"    -annotate "0x0+0+${margin1}"  "$text" "$1"
    else
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor"    -annotate "0x0+${margin1}+${margin1}"   "$text" "$1"
    fi
  fi
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
# shellcheck disable=SC2120
hash() {
  length=${1:-6}
  # shellcheck disable=SC2230
  if [[ -n $(which md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

force=0
help=0
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

## ----------- TERMINAL OUTPUT STUFF

initialise_output() {
  [[ "${BASH_SOURCE[0]:-}" != "${0}" ]] && sourced=1 || sourced=0
  [[ -t 1 ]] && piped=0 || piped=1 # detect if output is piped
  if [[ $piped -eq 0 ]]; then
    col_reset="\033[0m"
    col_red="\033[1;31m"
    col_grn="\033[1;32m"
    col_ylw="\033[1;33m"
  else
    col_reset=""
    col_red=""
    col_grn=""
    col_ylw=""
  fi

  [[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported
  if [[ $unicode -gt 0 ]]; then
    char_succ="✔"
    char_fail="✖"
    char_alrt="➨"
    char_wait="…"
    info_icon="🔎"
    config_icon="🖌️"
    clean_icon="🧹"
    require_icon="📎"
  else
    char_succ="OK "
    char_fail="!! "
    char_alrt="?? "
    char_wait="..."
    info_icon="(i)"
    config_icon="[c]"
    clean_icon="[c]"
    require_icon="[r]"
  fi
  error_prefix="${col_red}>${col_reset}"

  readonly nbcols=$(tput cols 2>/dev/null || echo 80)
  readonly wprogress=$((nbcols - 5))
}

out() { ((quiet)) || printf '%b\n' "$*"; }

progress() {
  ((quiet)) || (
    ((piped)) && out "$*" || printf "... %-${wprogress}b\r" "$*                                             "
  )
}

die()     { tput bel; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }

fail()    { tput bel; out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2; safe_exit; }

alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }                       # print error and continue

success() { out "${col_grn}${char_succ}${col_reset}  $*" ; }

announce(){ out "${col_grn}${char_wait}${col_reset}  $*"; sleep 1 ; }

debug()   { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2 ; }

log_to_file() { [[ -n ${log_file:-} ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"; }

lower_case()   { echo "$*" | awk '{print tolower($0)}' ; }
upper_case()   { echo "$*" | awk '{print toupper($0)}' ; }

slugify()     {
    # shellcheck disable=SC2020
  lower_case "$*" \
  | tr \
    'àáâäæãåāçćčèéêëēėęîïííīįìłñńôoöòóœøōõßśšûüùúūÿžźż' \
    'aaaaaaaaccceeeeeeeiiiiiiilnnooooooooosssuuuuuyzzz' \
  | awk '{
    gsub(/[^0-9a-z ]/,"");
    gsub(/^\s+/,"");
    gsub(/^s+$/,"");
    gsub(" ","-");
    print;
    }' \
  | cut -c1-50
  }

confirm() { is_set $force && return 0; read -r -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}

lower_case() { echo "$*" | awk '{print tolower($0)}'; }
upper_case() { echo "$*" | awk '{print toupper($0)}'; }

ask() {
  # $1 = variable name
  # $2 = question
  # $3 = default value
  # not using read -i because that doesn't work on MacOS
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]]; then
    eval "$1=\"$3\""
  else
    eval "$1=\"$ANSWER\""
  fi
}

trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  debug "$script_basename finished after $SECONDS seconds"
  exit 0
}

is_set() { [[ "$1" -gt 0 ]]; }
is_empty() { [[ -z "$1" ]]; }
is_not_empty() { [[ -n "$1" ]]; }

is_file() { [[ -f "$1" ]]; }
is_dir() { [[ -d "$1" ]]; }

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} created on ${col_grn}$script_created${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$script_modified${col_reset}"

  echo -n "Usage: $script_basename"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     } else {
          fulltext = fulltext sprintf("\n    %-10s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

show_tips() {
  grep <"${BASH_SOURCE[0]}" -v "\$0" |
    awk "
  /TIP: / {\$1=\"\"; gsub(/«/,\"$col_grn\"); gsub(/»/,\"$col_reset\"); print \"*\" \$0}
  /TIP:> / {\$1=\"\"; print \" $col_ylw\" \$0 \"$col_reset\"}
  "
}

check_script_settings() {
    ## leave this default action, it will make it easier to test your script
  if ((piped)); then
    debug "Skip dependencies for .env files"
  else
    out "## ${col_grn}dependencies${col_reset}: "
    out "$(list_dependencies | cut -d'|' -f1 | sort | xargs)"
    out " "
  fi

  if [[ -n $(filter_option_type flag) ]]; then
    out "## ${col_grn}boolean flags${col_reset}:"
    filter_option_type flag |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type option) ]]; then
    out "## ${col_grn}option defaults${col_reset}:"
    filter_option_type option |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type list) ]]; then
    out "## ${col_grn}list options${col_reset}:"
    filter_option_type list |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=(\${${name}[@]})\""
        else
          eval "echo -n \"$name=(\${${name}[@]})  \""
        fi
      done
    out " "
    out " "
  fi

  if [[ -n $(filter_option_type param) ]]; then
    if ((piped)); then
      debug "Skip parameters for .env files"
    else
      out "## ${col_grn}parameters${col_reset}:"
      filter_option_type param |
        while read -r name; do
          # shellcheck disable=SC2015
          ((piped)) && eval "echo \"$name=\\\"\${$name:-}\\\"\"" || eval "echo -n \"$name=\\\"\${$name:-}\\\"  \""
        done
      echo " "
    fi
  fi
}

filter_option_type() {
  list_options | grep "$1|" | cut -d'|' -f3 | sort | grep -v '^\s*$'
}

init_options() {
  local init_command
  init_command=$(list_options |
    grep -v "verbose|" |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /list/ {print $3 "=(); "}
    $1 ~ /secret/ {print $3 "=\"\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    eval "$init_command"
  fi
}

require_binaries() {
  local required_binary
  local install_instructions

  while read -r line; do
    required_binary=$(echo "$line" | cut -d'|' -f1)
    [[ -z "$required_binary" ]] && continue
    # shellcheck disable=SC2230
    path_binary=$(which "$required_binary" 2>/dev/null)
    [[ -n "$path_binary" ]] && debug "️$require_icon required [$required_binary] -> $path_binary"
    [[ -n "$path_binary" ]] && continue
    required_package=$(echo "$line" | cut -d'|' -f2)
    if [[ $(echo "$required_package" | wc -w) -gt 1 ]]; then
      # example: setver|basher install setver
      install_instructions="$required_package"
    else
      [[ -z "$required_package" ]] && required_package="$required_binary"
      if [[ -n "$install_package" ]]; then
        install_instructions="$install_package $required_package"
      else
        install_instructions="(install $required_package with your package manager)"
      fi
    fi
    alert "$script_basename needs [$required_binary] but it cannot be found"
    alert "1) install package  : $install_instructions"
    alert "2) check path       : export PATH=\"[path of your binary]:\$PATH\""
    die "Missing program/script [$required_binary]"
  done < <(list_dependencies)
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      debug "$clean_icon Create folder : [$folder]"
      mkdir -p "$folder"
    else
      debug "$clean_icon Cleanup folder: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

expects_single_params() { list_options | grep 'param|1|' >/dev/null; }
expects_optional_params() { list_options | grep 'param|?|' >/dev/null; }
expects_multi_param() { list_options | grep 'param|n|' >/dev/null; }

parse_options() {
  if [[ $# -eq 0 ]]; then
    show_usage >&2
    safe_exit
  fi

  ## first process all the -x --xxxx flags and options
  while true; do
    # flag <flag> is saved as $flag = 0/1
    # option <option> is saved as $option
    if [[ $# -eq 0 ]]; then
      ## all parameters processed
      break
    fi
    if [[ ! $1 == -?* ]]; then
      ## all flags/options processed
      break
    fi
    local save_option
    save_option=$(list_options |
      awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /list/ &&  "-"$2 == opt {print $3"+=($2); shift"}
        $1 ~ /list/ && "--"$3 == opt {print $3"=($2); shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift #noshow"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift #noshow"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        debug "$config_icon parameter: ${save_var}=$2"
      else
        debug "$config_icon flag: $save_option"
      fi
      eval "$save_option"
    else
      die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    show_usage
    check_last_version
    out "                                  "
    echo "### TIPS & EXAMPLES"
    show_tips

  ) && safe_exit

  ## then run through the given parameters
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    debug "$config_icon Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]] && die "need parameter [$param]"
      debug "$config_icon Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    debug "$config_icon No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_optional_params; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    debug "$config_icon Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params; do
      debug "$config_icon Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    debug "$config_icon No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param; then
    #debug "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    debug "$config_icon Expect : $multi_count multi parameter: $multi_param"
    ((multi_count > 1)) && die "cannot have >1 'multi' parameter: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      debug "$config_icon Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

count_words() { wc -w | awk '{ gsub(/ /,""); print}'; }

recursive_readlink() {
  [[ ! -L "$1" ]] && echo "$1" && return 0
  local file_folder
  local link_folder
  local link_name
  file_folder="$(dirname "$1")"
  # resolve relative to absolute path
  [[ "$file_folder" != /* ]] && link_folder="$(cd -P "$file_folder" &>/dev/null && pwd)"
  local symlink
  symlink=$(readlink "$1")
  link_folder=$(dirname "$symlink")
  link_name=$(basename "$symlink")
  [[ -z "$link_folder" ]] && link_folder="$file_folder"
  [[ "$link_folder" == \.* ]] && link_folder="$(cd -P "$file_folder" && cd -P "$link_folder" &>/dev/null && pwd)"
  debug "$info_icon Symbolic ln: $1 -> [$symlink]"
  recursive_readlink "$link_folder/$link_name"
}

lookup_script_data() {
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  readonly execution_day=$(date "+%Y-%m-%d")
  #readonly execution_year=$(date "+%Y")

  script_install_path="${BASH_SOURCE[0]}"
  debug "$info_icon Script path: $script_install_path"
  script_install_path=$(recursive_readlink "$script_install_path")
  debug "$info_icon Actual path: $script_install_path"
  readonly script_install_folder="$(dirname "$script_install_path")"
  if [[ -f "$script_install_path" ]]; then
    script_hash=$(hash <"$script_install_path" 8)
    script_lines=$(awk <"$script_install_path" 'END {print NR}')
  else
    # can happen when script is sourced by e.g. bash_unit
    script_hash="?"
    script_lines="?"
  fi

  # get shell/operating system/versions
  shell_brand="sh"
  shell_version="?"
  [[ -n "${ZSH_VERSION:-}" ]] && shell_brand="zsh" && shell_version="$ZSH_VERSION"
  [[ -n "${BASH_VERSION:-}" ]] && shell_brand="bash" && shell_version="$BASH_VERSION"
  [[ -n "${FISH_VERSION:-}" ]] && shell_brand="fish" && shell_version="$FISH_VERSION"
  [[ -n "${KSH_VERSION:-}" ]] && shell_brand="ksh" && shell_version="$KSH_VERSION"
  debug "$info_icon Shell type : $shell_brand - version $shell_version"

  readonly os_kernel=$(uname -s)
  os_version=$(uname -r)
  os_machine=$(uname -m)
  install_package=""
  case "$os_kernel" in
  CYGWIN* | MSYS* | MINGW*)
    os_name="Windows"
    ;;
  Darwin)
    os_name=$(sw_vers -productName)       # macOS
    os_version=$(sw_vers -productVersion) # 11.1
    install_package="brew install"
    ;;
  Linux | GNU*)
    if [[ $(which lsb_release) ]]; then
      # 'normal' Linux distributions
      os_name=$(lsb_release -i)    # Ubuntu
      os_version=$(lsb_release -r) # 20.04
    else
      # Synology, QNAP,
      os_name="Linux"
    fi
    [[ -x /bin/apt-cyg ]] && install_package="apt-cyg install"     # Cygwin
    [[ -x /bin/dpkg ]] && install_package="dpkg -i"                # Synology
    [[ -x /opt/bin/ipkg ]] && install_package="ipkg install"       # Synology
    [[ -x /usr/sbin/pkg ]] && install_package="pkg install"        # BSD
    [[ -x /usr/bin/pacman ]] && install_package="pacman -S"        # Arch Linux
    [[ -x /usr/bin/zypper ]] && install_package="zypper install"   # Suse Linux
    [[ -x /usr/bin/emerge ]] && install_package="emerge"           # Gentoo
    [[ -x /usr/bin/yum ]] && install_package="yum install"         # RedHat RHEL/CentOS/Fedora
    [[ -x /usr/bin/apk ]] && install_package="apk add"             # Alpine
    [[ -x /usr/bin/apt-get ]] && install_package="apt-get install" # Debian
    [[ -x /usr/bin/apt ]] && install_package="apt install"         # Ubuntu
    ;;

  esac
  debug "$info_icon System OS  : $os_name ($os_kernel) $os_version on $os_machine"
  debug "$info_icon Package mgt: $install_package"

  # get last modified date of this script
  script_modified="??"
  [[ "$os_kernel" == "Linux" ]] && script_modified=$(stat -c %y "$script_install_path" 2>/dev/null | cut -c1-16) # generic linux
  [[ "$os_kernel" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$script_install_path" 2>/dev/null)          # for MacOS

  debug "$info_icon Last modif : $script_modified"
  debug "$info_icon Script ID  : $script_lines lines / md5: $script_hash"
  debug "$info_icon Creation   : $script_created"
  debug "$info_icon Running as : $USER@$HOSTNAME"

  # if run inside a git repo, detect for which remote repo it is
  if git status &>/dev/null; then
    readonly git_repo_remote=$(git remote -v | awk '/(fetch)/ {print $2}')
    debug "$info_icon git remote : $git_repo_remote"
    readonly git_repo_root=$(git rev-parse --show-toplevel)
    debug "$info_icon git folder : $git_repo_root"
  else
    readonly git_repo_root=""
    readonly git_repo_remote=""
  fi

  # get script version from VERSION.md file - which is automatically updated by pforret/setver
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  # get script version from git tag file - which is automatically updated by pforret/setver
  [[ -n "$git_repo_root" ]] && [[ -n "$(git tag &>/dev/null)" ]] && script_version=$(git tag --sort=version:refname | tail -1)
}

prep_log_and_temp_dir() {
  tmp_file=""
  log_file=""
  if [[ -n "${tmp_dir:-}" ]]; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    debug "$config_icon tmp_file: $tmp_file"
    # you can use this temporary file in your program
    # it will be deleted automatically if the program ends without problems
  fi
  if [[ -n "${log_dir:-}" ]]; then
    folder_prep "$log_dir" 30
    log_file="$log_dir/$script_prefix.$execution_day.log"
    debug "$config_icon log_file: $log_file"
  fi
}

import_env_if_any() {
  env_files=("$script_install_folder/.env" "$script_install_folder/$script_prefix.env" "./.env" "./$script_prefix.env")

  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      debug "$config_icon Read config from [$env_file]"
      # shellcheck disable=SC1090
      source "$env_file"
    fi
  done
}

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

initialise_output  # output settings
lookup_script_data # set default values for flags & options
init_options
import_env_if_any # overwrite with .env if any
parse_options "$@" # overwrite with specified options if any
prep_log_and_temp_dir
main  # run main program
safe_exit # exit and clean up
