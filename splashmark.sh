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

option|l|log_dir|folder for log files |$HOME/log/$script_prefix
option|t|tmp_dir|folder for temp files|/tmp/$script_prefix
option|w|width|image width for resizing|1200
option|c|crop|image height for cropping|0
option|1|northwest|text to put in left top|
option|2|northeast|text to put in right top|{url}
option|3|southwest|text to put in left bottom|Created with pforret/splashmark
option|4|southeast|text to put in right bottom|{copyright2}
option|d|randomize|take a random picture in the first N results|1
option|e|effect|use effect chain on image: bw/blur/dark/grain/light/median/paint/pixel|
option|g|gravity|title alignment left/center/right|center
option|i|title|big text to put in center|
option|z|titlesize|font size for title|80
option|k|subtitle|big text to put in center|
option|j|subtitlesize|font size for subtitle|50
option|m|margin|margin for watermarks|30
option|o|fontsize|font size for watermarks|15
option|p|fonttype|font type family to use|FiraSansExtraCondensed-Bold.ttf
option|r|fontcolor|font color to use|FFFFFF
option|x|photographer|photographer name (empty: use name from API)|
option|u|url|photo URL override (empty: use URL from API)|

option|P|PIXABAY_ACCESSKEY|Pixabay access key|
option|U|UNSPLASH_ACCESSKEY|Unsplash access key|

param|1|action|action to perform: unsplash/file/url
param|?|input|URL or search term
param|?|output|output file
" | grep -v '^#' | grep -v '^\s*$'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  log_to_file "[$script_basename] $script_version started"
  require_binary curl

  action=$(lower_case "$action")
  case $action in
  unsplash)
    #TIP: use «splashmark unsplash» to download or search a Unsplash photo (requires free Unsplash API key)
    #TIP:> splashmark unsplash "https://unsplash.com/photos/lGo_E2XonWY" rose.jpg
    #TIP:> splashmark unsplash rose rose.jpg
    #TIP:> splashmark unsplash rose   (will generate unsplash.rose.jpg)
    [[ -z "${UNSPLASH_ACCESSKEY:-}" ]] && die "You need valid Unsplash API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
    image_source="unsplash"
    # shellcheck disable=SC2154
    [[ -z "$input" ]] && die "Need URL or search term to find an Unsplash photo"
    if [[ "$input" == *"://"* ]]; then
      [[ ! "$input" == *"://unsplash.com"* ]] && die "[$input] is not a unsplash.com URL"
      ### Unsplash URL: download one photo
      photo_id=$(basename "$input")
      # shellcheck disable=SC2154
      [[ -z "${output:-}" ]] && output="unsplash.$photo_id.jpg"
    else
      ### search for terms
      photo_id=$(search_images_unsplash "$input")
      photo_slug=$(slugify "$input")
      [[ -z "${output:-}" ]] && output="unsplash.$photo_slug.jpg"
    fi
    debug "Output file: [$output]"
    if [[ -n "$photo_id" ]]; then
      debug "Unsplash photo ID = [$photo_id]"
      image_file=$(download_image_unsplash "$photo_id")
      download_metadata_unsplash "$photo_id"
      image_modify "$image_file" "$output"
      out "$output"
    fi
    ;;

  pixabay)
    #TIP: use «splashmark pixabay» to download or search a Pixabay photo (requires free Pixabay API key)
    #TIP:> splashmark pixabay "https://pixabay.com/photos/rose-flower-love-romance-beautiful-729509/" rose.jpg
    #TIP:> splashmark pixabay rose rose.jpg
    #TIP:> splashmark pixabay rose   (will generate pixabay.rose.jpg)
    [[ -z "${PIXABAY_ACCESSKEY:-}" ]] && die "You need valid Pixabay API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
    image_source="pixabay"
    # shellcheck disable=SC2154
    [[ -z "$input" ]] && die "Need URL or search term to find an Pixabay photo"
    if [[ "$input" == *"://"* ]]; then
      [[ ! "$input" == *"://pixabay.com"* ]] && die "[$input] is not a pixabay.com URL"
      ### Unsplash URL: download one photo
      photo_id=$(basename "${input//-//}")
      # shellcheck disable=SC2154
      [[ -z "${output:-}" ]] && output="$photo_id.jpg"
    else
      ### search for terms
      photo_id=$(search_images_pixabay "$input")
      photo_slug=$(slugify "$input")
      [[ -z "${output:-}" ]] && output="pixabay.$photo_slug.jpg"
    fi
    debug "Output file: [$output]"
    if [[ -n "$photo_id" ]]; then
      debug "Pixabay photo ID = [$photo_id]"
      image_file=$(download_image_pixabay "$photo_id")
      download_metadata_pixabay "$photo_id"
      image_modify "$image_file" "$output"
      out "$output"
    fi
    ;;

  file | f)
    #TIP: use «splashmark file» to add texts and effects to a existing image
    #TIP:> splashmark file waterfall.jpg sources/original.jpg
    #TIP:> splashmark --title "Strawberry" -w 1280 -c 640 -e dark,median,grain file sources/original.jpg waterfall.jpg
    image_source="file"
    [[ ! -f "$input" ]] && die "Cannot find input file [$input]"
    image_modify "$input" "$output"
    out "$output"
    ;;

  url | u)
    #TIP: use «splashmark url» to add texts and effects to a image that will be downloaded from a URL
    #TIP:> splashmark file waterfall.jpg "https://i.imgur.com/rbXZcVH.jpg"
    #TIP:> splashmark -w 1280 -c 640 -4 "Photographer: John Doe" -e dark,median,grain url "https://i.imgur.com/rbXZcVH.jpg" waterfall.jpg
    image_source="url"
    image_file=$(download_image_from_url "$input")
    [[ ! -f "$image_file" ]] && die "Cannot download input image [$input]"
    image_modify "$image_file" "$output"
    out "$output"
    ;;

  check | env)
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
#TIP:> splashmark -w 1280 -c 640 -z 100 -i "<user>/<repo>" -k "line 1\nline 2" -r EEEEEE -e median,dark,grain unsplash <keyword>
#TIP: to create a social image for Instagram
#TIP:> splashmark -w 1080 -c 1080 -z 150 -i "Carpe diem" -e dark pixabay clouds clouds.jpg
#TIP: to create a social image for Facebook
#TIP:> splashmark -w 1200 -c 630 -i "20 worldwide destinations\nwith the best beaches\nfor unforgettable holidays" -e dark unsplash copacabana

#####################################################################
## Put your helper scripts here
#####################################################################

### Unsplash API stuff

cached_unsplash_api() {
  # $1 = relative API URL
  # $2 = jq query path
  require_binary jq
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
  if [[ ! -f "$cached" ]]; then
    # only get the data once
    debug "Unsplash API = [$show_url]"
    curl -s "$full_url" >"$cached"
    if [[ $(wc <"$cached" -c) -lt 10 ]]; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
      return 1
    fi
    if grep -q "Rate Limit Exceeded" "$cached"; then
      # remove if response is API throttling starts
      rm "$cached"
      alert "API call to [$1] was throttled - remember it's limited to 50 req/hr!"
      return 2
    fi
  else
    debug "API = [$cached]"
  fi
  jq <"$cached" "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

download_metadata_unsplash() {
  # only get metadata if it was not yet specified as an option
  [[ -z "${photographer:-}" ]] && photographer=$(cached_unsplash_api "/photos/$1" ".user.name")
  [[ -z "${url:-}" ]] && url="$(cached_unsplash_api "/photos/$1" ".links.html")"
  debug "META: Photographer: $photographer"
  debug "META: URL: $url"
}

download_image_unsplash() {
  # $1 = photo_id
  # returns path of downloaded file
  photo_id=$(basename "/a/$1") # to avoid problems with image ID that start with '-'
  image_url=$(cached_unsplash_api "/photos/$photo_id" .urls.regular)
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

search_images_unsplash() {
  # $1 = keyword(s)
  # returns first result
  # shellcheck disable=SC2154
  if [[ "$randomize" == 1 ]]; then
    cached_unsplash_api "/search/photos/?query=$1" ".results[0].id"
  else
    choose_from=$(cached_unsplash_api "/search/photos/?query=$1" .results[].id | wc -l)
    debug "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    debug "PICK: photo $chosen from first $choose_from results"
    cached_unsplash_api "/search/photos/?query=$1" ".results[$chosen].id"
  fi
}

### Pixabay API stuff

cached_pixabay_api() {
  # $1 = relative API URL
  # $2 = jq query path
  # https://pixabay.com/api/docs/
  # https://pixabay.com/api/?key={ KEY }&q=yellow+flowers&image_type=photo
  require_binary jq
  local uniq
  local api_endpoint="https://pixabay.com/api/"
  local full_url="$api_endpoint$1"
  local show_url="$api_endpoint$1"
  if [[ $full_url =~ "?" ]]; then
    # already has querystring
    full_url="$full_url&key=$PIXABAY_ACCESSKEY"
  else
    # no querystring yet
    full_url="$full_url?key=$PIXABAY_ACCESSKEY"
  fi
  uniq=$(echo "$full_url" | hash 8)
  # shellcheck disable=SC2154
  local cached="$tmp_dir/pixabay.$uniq.json"
  debug "API URL   = [$full_url]"
  debug "API Cache = [$cached]"
  if [[ ! -f "$cached" ]]; then
    # only get the data once
    debug "Pixabay API = [$show_url]"
    curl -s "$full_url" >"$cached"
    if [[ $(wc <"$cached" -c) -lt 10 ]]; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
      return 1
    fi
  fi
  jq <"$cached" "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

download_metadata_pixabay() {
  # only get metadata if it was not yet specified as an option
  [[ -z "${photographer:-}" ]] && photographer=$(cached_pixabay_api "?id=$photo_id&image_type=photo" ".hits[0].user")
  [[ -z "${url:-}" ]] && url="https://pixabay.com/photos/$photo_id/"
  debug "META: Photographer: $photographer"
  debug "META: URL: $url"
}

download_image_pixabay() {
  # $1 = photo_id
  # returns path of downloaded file
  # https://pixabay.com/api/?key=<key>&id=<id>+flowers&image_type=photo
  photo_id=$(basename "/a/$1") # to avoid problems with image ID that start with '-'
  image_url=$(cached_pixabay_api "?id=$photo_id&image_type=photo" .hits[0].largeImageURL)
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

search_images_pixabay() {
  # $1 = keyword(s)
  # returns first result
  # https://pixabay.com/api/?key={ KEY }&q=yellow+flowers&image_type=photo
  # shellcheck disable=SC2154
  if [[ "$randomize" == 1 ]]; then
    cached_pixabay_api "?image_type=photo&q=$1" ".hits[0].id"
  else
    choose_from=$(cached_pixabay_api "?image_type=photo&q=$1" .hits[].id | wc -l)
    debug "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    debug "PICK: photo $chosen from first $choose_from results"
    cached_pixabay_api "?image_type=photo&q=$1" ".hits[$chosen].id"
  fi
}

### Image URL stuff

download_image_from_url() {
  # $1 = url
  local uniq
  local extension="jpg"
  [[ "$1" =~ .png ]] && extension="png"
  [[ "$1" =~ .gif ]] && extension="gif"
  uniq=$(echo "$1" | hash 8)
  cached_image="$tmp_dir/image.$uniq.$extension"
  if [[ ! -f "$cached_image" ]]; then
    debug "IMG = [$1]"
    curl -s -o "$cached_image" "$1"
  else
    debug "IMG = [$cached_image]"
  fi
  echo "$cached_image"
}

### Modify images

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
  require_binary exiftool

  # $1 = type
  # $2 = filename
  # https://exiftool.org/TagNames/index.html
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
  #  Headline                        : Headline
  #  ImageDescription                : ImageDescription
  #  Keywords                        : Keywords
  #  Object Name                     : Document Title
  #  Owner Name                      : OwnerName
  #  Source                          : Source
  #  Special Instructions            : Instructions
  #  Sub-location                    : Sub-location
  #  Supplemental Categories         : OtherCategories
  #  Urgency                         : 1 (most urgent)
  #  Writer-Editor                   : Caption Writer
  set_exif "$2" "Writer-Editor" "https://github.com/pforret/splashmark"
  if [[ "$1" == "unsplash" ]]; then
    ## metadata comes from Unsplash/Pixabay
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

  require_binary convert imagemagick

  font_list="$tmp_dir/magick.fonts.txt"
  if [[ ! -f "$font_list" ]]; then
    convert -list font | awk -F: '/Font/ {gsub(" ","",$2); print $2 }' >"$font_list"
  fi
  if [[ -f "$fonttype" ]]; then
    debug "FONT [$fonttype] exists as a font file"
  elif grep -q "$fonttype" "$font_list"; then
    debug "FONT [$fonttype] exists as a standard font"
  elif [[ -f "$script_install_folder/fonts/$fonttype" ]]; then
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
    convert "$1" -gravity Center -resize "${width}"x -quality 95% "$2"
  fi
  ## set EXIF/IPTC tags
  set_metadata_tags "$image_source" "$2"

  ## do visual effects
  # shellcheck disable=SC2154
  if [[ -n "$effect" ]]; then
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
    echo "$1" |
      sed "s|{copyright}|Photo by {photographer} on Unsplash.com|" |
      sed "s|{copyright2}|© {photographer} » Unsplash.com|" |
      sed "s|{photographer}|$photographer|" |
      sed "s|{url}|$url|" |
      sed "s|https://||"
    ;;
  pixabay)
    echo "$1" |
      sed "s|{copyright}|Photo by {photographer} on Pixabay.com|" |
      sed "s|{copyright2}|© {photographer} » Pixabay.com|" |
      sed "s|{photographer}|$photographer|" |
      sed "s|{url}|$url|" |
      sed "s|https://||"
    ;;
  *)
    echo "$1" |
      sed "s|{copyright}| |" |
      sed "s|{copyright2}| |" |
      sed "s|{photographer}| |" |
      sed "s|{url}| |" |
      sed "s|https://||"
    ;;
  esac
}

rescale_weight(){
  local percent="$1"
  local percent0="$2"
  local percent100="$3"
  local rescaled
  if [[ "${4:-int}" == "float" ]] ; then
    rescaled=$(awk "BEGIN {print $percent0 + ( $percent100 - $percent0 ) * $percent / 100 }")
  else
    rescaled=$(( percent0 + ( percent100 - percent0 ) * percent / 100 ))
  fi
  debug "Rescaled: $percent => $rescaled"
  echo "$rescaled"
}

image_effect() {
  # $1 = image path
  # $2 = effect name
  # shellcheck disable=SC2154
  [[ ! -f "$1" ]] && return 1
  require_binary mogrify imagemagick

  for fx1 in $(echo "$effect" | tr ',' "\n"); do
    debug "Effect : $fx1"
    # shellcheck disable=SC2001
    percent="$(echo "$fx1" | sed 's/[^0-9]//g')"
    percent="${percent:-20}"
    debug "Weight : $percent %"
    case "$fx1" in
    blur*)      weight=$(rescale_weight "$percent" 0 50);  mogrify -blur "${weight:-5}x${weight:-5}" "$1" ;;
    bw)         mogrify -modulate 100,0,100 "$1" ;;
    dark*)      weight=$(rescale_weight "$percent" 0 100); mogrify -fill black -colorize "${weight}%" "$1" ;;
    desat*)     weight=$(rescale_weight "$percent" 100 0); mogrify -modulate "100,$weight,100" "$1" ;;
    grain*)     weight=$(rescale_weight "$percent" 0 2 float); mogrify -attenuate "${weight}" +noise Gaussian "$1" ;;
    light*)     weight=$(rescale_weight "$percent" 0 100); mogrify -fill white -colorize "${weight}%" "$1" ;;
    median*)    weight=$(rescale_weight "$percent" 0 10); mogrify -median "${weight}" "$1" ;;
    monochrome) mogrify -modulate 100,0,100 "$1" ;;
    noise*)     weight=$(rescale_weight "$percent" 0 2 float); mogrify -attenuate "${weight}" +noise Gaussian "$1" ;;
    norm)       mogrify -normalize "$1" ;;
    normalize)  mogrify -normalize "$1" ;;
    paint*)     weight=$(rescale_weight "$percent" 0 10); mogrify -paint "${weight}" "$1" ;;
    pixel*)     shrink=$(awk "BEGIN {print int(250/$percent) }"); expand=$(awk "BEGIN {print int(10000/$shrink) }"); mogrify -resize "${shrink}%" -scale "${expand}%" "$1" ;;
    sketch*)    weight=$(rescale_weight "$percent" 0 10);  mogrify -sketch "${weight}x${weight}+45" "$1" ;;
    vignette*)  weight=$(rescale_weight "$percent" 200 20);  large=$(rescale_weight "$percent" 100 0); mogrify -background black -vignette "0x${weight}-${large}-${large}"  "$1" ;;
    *)
      # shellcheck disable=SC2086
      eval mogrify $effect "$1"
      ;;
    esac
  done
}

image_watermark() {
  # $1 = image path
  # $2 = gravity
  # $3 = text

  [[ ! -f "$1" ]] && return 1
  require_binary mogrify imagemagick

  # shellcheck disable=SC2154
  char1=$(upper_case "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008"
    ;;
  *)
    shadow_color="FFF8"
    ;;
  esac
  text=$(text_resolve "$3")

  debug "MARK: [$text] in $2 corner ..."
  # shellcheck disable=SC2154
  margin2=$((margin + 1))
  # shellcheck disable=SC2154
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$fontcolor" -annotate "0x0+${margin}+${margin}" "$text" "$1"
}

choose_position() {
  position="$1"
  # shellcheck disable=SC2154
  case $(lower_case "$gravity") in
  left | west) position="${position}West" ;;
  right | east) position="${position}East" ;;
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
    shadow_color="0008"
    ;;
  *)
    shadow_color="FFF8"
    ;;
  esac
  margin1=$((margin * 3))
  margin2=$((margin1 + 1))
  if [[ -n "$title" ]]; then
    text=$(text_resolve "$title")
    position=""
    [[ -n "$subtitle" ]] && position="North"
    position=$(choose_position "$position")
    debug "MARK: title [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(lower_case "$gravity") == "center" ]]; then
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$shadow_color" -annotate "0x0+1+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$fontcolor" -annotate "0x0+0+${margin1}" "$text" "$1"
    else
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$titlesize" -fill "#$fontcolor" -annotate "0x0+${margin1}+${margin1}" "$text" "$1"
    fi
  fi
  if [[ -n "$subtitle" ]]; then
    text=$(text_resolve "$subtitle")
    position=""
    [[ -n "$title" ]] && position="South"
    position=$(choose_position "$position")
    debug "MARK: subtitle [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(lower_case "$gravity") == "center" ]]; then
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+1+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor" -annotate "0x0+0+${margin1}" "$text" "$1"
    else
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor" -annotate "0x0+${margin1}+${margin1}" "$text" "$1"
    fi
  fi
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################
#####################################################################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
hash() {
  length=${1:-6}
  if [[ -n $(command -v md5sum) ]]; then
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

### stdout/stderr output
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
    char_succ="✅"
    char_fail="⛔"
    char_alrt="✴️"
    char_wait="⏳"
    info_icon="🌼"
    config_icon="🌱"
    clean_icon="🧽"
    require_icon="🔌"
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
}

out() { ((quiet)) && true || printf '%b\n' "$*"; }
debug() { if ((verbose)); then out "${col_ylw}# $* ${col_reset}" >&2; else true; fi; }
die() {
  out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2
  tput bel
  safe_exit
}
alert() { out "${col_red}${char_alrt}${col_reset}: $*" >&2; }
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
announce() {
  out "${col_grn}${char_wait}${col_reset}  $*"
  sleep 1
}
progress() {
  ((quiet)) || (
    local screen_width
    screen_width=$(tput cols 2>/dev/null || echo 80)
    local rest_of_line
    rest_of_line=$((screen_width - 5))

    if flag_set ${piped:-0}; then
      out "$*" >&2
    else
      printf "... %-${rest_of_line}b\r" "$*                                             " >&2
    fi
  )
}

log_to_file() { [[ -n ${log_file:-} ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"; }

### string processing
lower_case() { echo "$*" | tr '[:upper:]' '[:lower:]'; }
upper_case() { echo "$*" | tr '[:lower:]' '[:upper:]'; }

slugify() {
  # slugify <input> <separator>
  # slugify "Jack, Jill & Clémence LTD"      => jack-jill-clemence-ltd
  # slugify "Jack, Jill & Clémence LTD" "_"  => jack_jill_clemence_ltd
  separator="${2:-}"
  [[ -z "$separator" ]] && separator="-"
  # shellcheck disable=SC2020
  echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
    awk '{
          gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_]/," ",$0);
          gsub(/^  */,"",$0);
          gsub(/  *$/,"",$0);
          gsub(/  */,"-",$0);
          gsub(/[^a-z0-9\-]/,"");
          print;
          }' |
    sed "s/-/$separator/g"
}

title_case() {
  # title_case <input> <separator>
  # title_case "Jack, Jill & Clémence LTD"     => JackJillClemenceLtd
  # title_case "Jack, Jill & Clémence LTD" "_" => Jack_Jill_Clemence_Ltd
  separator="${2:-}"
  # shellcheck disable=SC2020
  echo "$1" |
    tr '[:upper:]' '[:lower:]' |
    tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
    awk '{ gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_-]/," ",$0); print $0; }' |
    awk '{
          for (i=1; i<=NF; ++i) {
              $i = toupper(substr($i,1,1)) tolower(substr($i,2))
          };
          print $0;
          }' |
    sed "s/ /$separator/g" |
    cut -c1-50
}

### interactive
confirm() {
  # $1 = question
  flag_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

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

safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  trap - INT TERM EXIT
  debug "$script_basename finished after $SECONDS seconds"
  exit 0
}

flag_set() { [[ "$1" -gt 0 ]]; }

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$script_modified${col_reset}"
  out "Description: package_description"
  echo -n "Usage: $script_basename"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [option] %s",$2,$3 " <?>",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /list/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [list] %s (array)",$2,$3 " <?>",$4) ;
    fulltext = fulltext "  [default empty]";
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secret] %s",$2,$3,"?",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     }
     if($2 == "?"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s (optional)","<"$3">",$4);
          oneline  = oneline " <" $3 "?>"
     }
     if($2 == "n"){
          fulltext = fulltext sprintf("\n    %-17s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

check_last_version() {
  (
    # shellcheck disable=SC2164
    pushd "$script_install_folder" &>/dev/null
    if [[ -d .git ]]; then
      local remote
      remote="$(git remote -v | grep fetch | awk 'NR == 1 {print $2}')"
      progress "Check for latest version - $remote"
      git remote update &>/dev/null
      if [[ $(git rev-list --count "HEAD...HEAD@{upstream}" 2>/dev/null) -gt 0 ]]; then
        out "There is a more recent update of this script - run <<$script_prefix update>> to update"
      fi
    fi
    # shellcheck disable=SC2164
    popd &>/dev/null
  )
}

update_script_to_latest() {
  # run in background to avoid problems with modifying a running interpreted script
  (
    sleep 1
    cd "$script_install_folder" && git pull
  ) &
}

show_tips() {
  ((sourced)) && return 0
  # shellcheck disable=SC2016
  grep <"${BASH_SOURCE[0]}" -v '$0' |
    awk \
      -v green="$col_grn" \
      -v yellow="$col_ylw" \
      -v reset="$col_reset" \
      '
      /TIP: /  {$1=""; gsub(/«/,green); gsub(/»/,reset); print "*" $0}
      /TIP:> / {$1=""; print " " yellow $0 reset}
      ' |
    awk \
      -v script_basename="$script_basename" \
      -v script_prefix="$script_prefix" \
      '{
      gsub(/\$script_basename/,script_basename);
      gsub(/\$script_prefix/,script_prefix);
      print ;
      }'
}

check_script_settings() {
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

require_binary() {
  binary="$1"
  path_binary=$(command -v "$binary" 2>/dev/null)
  [[ -n "$path_binary" ]] && debug "️$require_icon required [$binary] -> $path_binary" && return 0
  #
  words=$(echo "${2:-}" | wc -l)
  case $words in
  0) install_instructions="$install_package $1" ;;
  1) install_instructions="$install_package $2" ;;
  *) install_instructions="$2" ;;
  esac
  alert "$script_basename needs [$binary] but it cannot be found"
  alert "1) install package  : $install_instructions"
  alert "2) check path       : export PATH=\"[path of your binary]:\$PATH\""
  die "Missing program/script [$binary]"
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
  debug "$info_icon Linked path: $script_install_path"
  readonly script_install_folder="$(cd -P "$(dirname "$script_install_path")" && pwd)"
  debug "$info_icon In folder  : $script_install_folder"
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
    if [[ $(command -v lsb_release) ]]; then
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

initialise_output  # output settings
lookup_script_data # find installation folder

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

init_options      # set default values for flags & options
import_env_if_any # overwrite with .env if any

if [[ $sourced -eq 0 ]]; then
  parse_options "$@"    # overwrite with specified options if any
  prep_log_and_temp_dir # clean up debug and temp folder
  main                  # run main program
  safe_exit             # exit and clean up
else
  # just disable the trap, don't execute main
  trap - INT TERM EXIT
fi
