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
option|1|northwest|text to put in left top|
option|2|northeast|text to put in right top|{url}
option|3|southwest|text to put in left bottom|
option|4|southeast|text to put in right bottom|{copyright2}
option|c|crop|image height for cropping|0
option|d|randomize|take a random picture in the first N results|1
option|e|effect|use effect chain on image: bw/blur/dark/grain/light/median/paint/pixel|
option|g|gravity|title alignment left/center/right|center
option|i|title|big text to put in center|
option|j|subtitlesize|font size for subtitle|50
option|k|subtitle|big text to put in center|
option|l|log_dir|folder for log files |log
option|m|margin|margin for watermarks|15
option|o|fontsize|font size for watermarks|15
option|p|fonttype|font type family to use|FiraSansExtraCondensed-Bold.ttf
option|r|fontcolor|font color to use|FFFFFF
option|t|tmp_dir|folder for temp files|.tmp
option|w|width|image width for resizing|1200
option|x|photographer|photographer name (empty: get from Unsplash)|
option|z|titlesize|font size for title|80
param|1|action|action to perform: download/search/file/url
param|1|output|output file
param|1|input|URL or search term
" | grep -v '^#'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  log "Program: $script_basename $script_version"
  log "Updated: $script_modified"
  log "Run as : $USER@$HOSTNAME"
  verify_programs awk basename cut date dirname find grep head mkdir sed stat tput uname wc exiftool convert mogrify
  prep_log_and_temp_dir

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
      log "Found photo ID = $photo_id"
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
      log "Found photo ID = $photo_id"
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
    log "API = [$show_url]"
    curl -s "$full_url" > "$cached"
    if [[ $(< "$cached" wc -c) -lt 10 ]] ; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
    fi
  else
    log "API = [$cached]"
  fi
  < "$cached" jq "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

get_metadata_from_unsplash() {
  # only get metadata if it was not yet specified as an option
  [[ -z "$photographer" ]]  && photographer=$(unsplash_api "/photos/$1" ".user.name")
  [[ -z "$url" ]] && url=$(unsplash_api "/photos/$1" ".links.html")
}

download_image_from_unsplash() {
  # $1 = photo_id
  # returns path of downloaded file
  photo_id=$(basename "$1")
  image_url=$(unsplash_api "/photos/$photo_id" .urls.regular)
  cached_image="$tmp_dir/$photo_id.jpg"
  if [[ ! -f "$cached_image" ]]; then
    log "IMG = [$image_url]"
    curl -s -o "$cached_image" "$image_url"
  else
    log "IMG = [$cached_image]"
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
    log "IMG = [$1]"
    curl -s -o "$cached_image" "$1"
  else
    log "IMG = [$cached_image]"
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
    log "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    log "PICK: photo $chosen from first $choose_from results"
    unsplash_api "/search/photos/?query=$1" ".results[$chosen].id"
  fi
}

set_exif() {
  filename="$1"
  exif_key="$2"
  exif_val="$3"

  if [[ -n "$exif_val" ]]; then
    log "EXIF: set [$exif_key] to [$exif_val] for [$filename]"
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
  set_exif "$2" "Writer-Editor" "$script_basename"
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
    log "FONT [$fonttype] exists as a font file"
  elif grep -q "$fonttype" "$font_list" ; then
    log "FONT [$fonttype] exists as a standard font"
  elif [[ -f "$script_install_folder/fonts/$fonttype" ]] ; then
    fonttype="$script_install_folder/fonts/$fonttype"
    log "FONT [$fonttype] exists as a splashmark font"
  else
    die "FONT [$fonttype] cannot be found on this system"
  fi

  ## scale and crop
  # shellcheck disable=SC2154
  if [[ $crop -gt 0 ]]; then
    log "CROP: image to $width x $crop --> $2"
    convert "$1" -gravity Center -resize "${width}x${crop}^" -crop "${width}x${crop}+0+0" +repage -quality 95% "$2"
  else
    log "SIZE: to $width wide --> $2"
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
  for fx1 in $(echo "$effect" | tr ',' "\n") ; do
    log "EFX : $fx1"
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

  # shellcheck disable=SC2154
  char1=$(upper_case "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008" ;;
  *)
    shadow_color="FFF8" ;;
  esac
  text=$(text_resolve "$3")

  log "MARK: [$text] in $2 corner ..."
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
    log "MARK: title [$text] in $position ..."
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
    log "MARK: subtitle [$text] in $position ..."
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

script_modified="??"
os_name=$(uname -s)
[[ "$os_name" == "Linux" ]] && script_modified=$(stat -c %y "${BASH_SOURCE[0]}" 2>/dev/null | cut -c1-16) # generic linux
[[ "$os_name" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "${BASH_SOURCE[0]}" 2>/dev/null)          # for MacOS

force=0
help=0

## ----------- TERMINAL OUTPUT STUFF

[[ -t 1 ]] && piped=0 || piped=1 # detect if out put is piped
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

[[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported

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

if [[ $unicode -gt 0 ]]; then
  char_succ="✔"
  char_fail="✖"
  char_alrt="➨"
  char_wait="…"
else
  char_succ="OK "
  char_fail="!! "
  char_alrt="?? "
  char_wait="..."
fi

readonly nbcols=$(tput cols || echo 80)
#readonly nbrows=$(tput lines)
readonly wprogress=$((nbcols - 5))

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

log()   { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2 ; }

log_to_file(){ echo "$(date '+%H:%M:%S') | $*" >> "$log_file" ; }

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

error_prefix="${col_red}>${col_reset}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  log "$script_basename finished after $SECONDS seconds"
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

init_options() {
  local init_command
  init_command=$(list_options |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    log "init_options: options/flags initialised"
    eval "$init_command"
  fi
}

verify_programs() {
  os_name=$(uname -s)
  os_version=$(uname -v)
  log "Running: on $os_name ($os_version)"
  list_programs=$(echo "$*" | sort -u | tr "\n" " ")
  log "Verify : $list_programs"
  for prog in "$@"; do
    # shellcheck disable=SC2230
    if [[ -z $(which "$prog") ]]; then
      die "$script_basename needs [$prog] but this program cannot be found on this [$os_name] machine"
    fi
  done
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      log "Create folder : [$folder]"
      mkdir "$folder"
    else
      log "Cleanup folder: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

expects_single_params() {
  list_options | grep 'param|1|' >/dev/null
}
expects_multi_param() {
  list_options | grep 'param|n|' >/dev/null
}

parse_options() {
  if [[ $# -eq 0 ]]; then
    show_usage >&2
    safe_exit
  fi

  ## first process all the -x --xxxx flags and options
  #set -x
  while true; do
    # flag <flag> is savec as $flag = 0/1
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
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        log "Found  : ${save_var}=$2"
      else
        log "Found  : $save_option"
      fi
      eval "$save_option"
    else
      die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    echo "### USAGE"
    show_usage
    echo ""
    echo "### TIPS & EXAMPLES"
    show_tips
    safe_exit
  )

  ## then run through the given parameters
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | wc -w)
    log "Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]] && die "need parameter [$param]"
      log "Found  : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    log "No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_multi_param; then
    #log "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    log "Expect : $multi_count multi parameter: $multi_param"
    ((multi_count > 1)) && die "cannot have >1 'multi' parameter: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      log "Found  : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

lookup_script_data() {
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  # shellcheck disable=SC2034
  readonly execution_day=$(date "+%Y-%m-%d")
  # shellcheck disable=SC2034
  readonly execution_year=$(date "+%Y")

  if [[ -z $(dirname "${BASH_SOURCE[0]}") ]]; then
    # script called without path ; must be in $PATH somewhere
    # shellcheck disable=SC2230
    script_install_path=$(which "${BASH_SOURCE[0]}")
    if [[ -n $(readlink "$script_install_path") ]]; then
      # when script was installed with e.g. basher
      script_install_path=$(readlink "$script_install_path")
    fi
    script_install_folder=$(dirname "$script_install_path")
  else
    # script called with relative/absolute path
    script_install_folder=$(dirname "${BASH_SOURCE[0]}")
    # resolve to absolute path
    script_install_folder=$(cd "$script_install_folder" && pwd)
    if [[ -n "$script_install_folder" ]]; then
      script_install_path="$script_install_folder/$script_basename"
    else
      script_install_path="${BASH_SOURCE[0]}"
      script_install_folder=$(dirname "${BASH_SOURCE[0]}")
    fi
    if [[ -n $(readlink "$script_install_path") ]]; then
      # when script was installed with e.g. basher
      script_install_path=$(readlink "$script_install_path")
      script_install_folder=$(dirname "$script_install_path")
    fi
  fi
  log "Executable: [$script_install_path]"
  log "In folder : [$script_install_folder]"

  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
}

prep_log_and_temp_dir() {
  tmp_file=""
  log_file=""
  # shellcheck disable=SC2154
  if is_not_empty "$tmp_dir"; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    log "tmp_file: $tmp_file"
    # you can use this teporary file in your program
    # it will be deleted automatically if the program ends without problems
  fi
  # shellcheck disable=SC2154
  if [[ -n "$log_dir" ]]; then
    folder_prep "$log_dir" 7
    log_file=$log_dir/$script_prefix.$execution_day.log
    log "log_file: $log_file"
    echo "$(date '+%H:%M:%S') | [$script_basename] $script_version started" >>"$log_file"
  fi
}

import_env_if_any() {
  if [[ -f "$script_install_folder/.env" ]]; then
    log "Read config from [$script_install_folder/.env]"
    # shellcheck disable=SC1090
    source "$script_install_folder/.env"
  fi
  if [[ -f "./.env" ]]; then
    log "Read config from [./.env]"
    # shellcheck disable=SC1091
    source "./.env"
  fi
}

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

lookup_script_data

# set default values for flags & options
init_options

# overwrite with .env if any
import_env_if_any

# overwrite with specified options if any
parse_options "$@"

# run main program
main

# exit and clean up
safe_exit
