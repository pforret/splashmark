#!/usr/bin/env bash
### Created by Peter Forret ( pforret ) on 2020-09-28
script_version="0.0.0" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_created="2020-09-28"
readonly script_description="Mark up images (unspash/pixabay/URL) with titles, effects and resize"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

function Option:config() {
  grep <<<"
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more

option|l|log_dir|folder for log files |$HOME/log/$script_prefix
option|t|tmp_dir|folder for temp files|/tmp/$script_prefix
option|w|width|image width for resizing|1200
option|c|crop|image height for cropping|0
option|s|preset|image size preset
option|S|resize|multiply preset with factor
option|1|northwest|text to put in left top|
option|2|northeast|text to put in right top|{url}
option|3|southwest|text to put in left bottom|Created with pforret/splashmark
option|4|southeast|text to put in right bottom|{copyright2}
option|d|randomize|take a random picture in the first N results|1
option|D|number|take the Nth picture from query results|1
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
choice|1|action|action to perform|unsplash,file,url,sizes,check,env,update
param|?|input|URL or search term
param|?|output|output file
" -v -e '^#' -e '^\s*$'
}

#####################################################################
## Put your main script here
#####################################################################

Script:main() {
  IO:log "[$script_basename] $script_version started"
  Os:require curl

  # shellcheck disable=SC2154
  case "${action,,}" in
unsplash)
  #TIP: use «splashmark unsplash» to download or search a Unsplash photo (requires free Unsplash API key)
  #TIP:> splashmark unsplash "https://unsplash.com/photos/lGo_E2XonWY" rose.jpg
  #TIP:> splashmark unsplash rose rose.jpg
  #TIP:> splashmark unsplash rose   (will generate unsplash.rose.jpg)
  [[ -z "${UNSPLASH_ACCESSKEY:-}" ]] && IO:die "You need valid Unsplash API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
  image_source="unsplash"
  # shellcheck disable=SC2154
  [[ -z "$input" ]] && IO:die "Need URL or search term to find an Unsplash photo"
  if [[ "$input" == *"://"* ]]; then
    [[ ! "$input" == *"://unsplash.com"* ]] && IO:die "[$input] is not a unsplash.com URL"
    ### Unsplash URL: download one photo
    photo_id=$(basename "$input")
    # shellcheck disable=SC2154
    [[ -z "${output:-}" ]] && output="unsplash.$photo_id.jpg"
  else
    ### search for terms
    photo_id=$(unsplash:search "$input")
    local photo_slug
    photo_slug=$(Str:slugify "$input")
    [[ -z "${output:-}" ]] && output="unsplash.$photo_slug.jpg"
  fi
  IO:debug "Output file: [$output]"
  if [[ -n "$photo_id" ]]; then
    IO:debug "Unsplash photo ID = [$photo_id]"
    local image_file
    image_file=$(unsplash:download "$photo_id")
    unsplash:metadata "$photo_id"
    Img:modify "$image_file" "$output"
    IO:print "$output"
  fi
  ;;

pixabay)
  #TIP: use «splashmark pixabay» to download or search a Pixabay photo (requires free Pixabay API key)
  #TIP:> splashmark pixabay "https://pixabay.com/photos/rose-flower-love-romance-beautiful-729509/" rose.jpg
  #TIP:> splashmark pixabay rose rose.jpg
  #TIP:> splashmark pixabay rose   (will generate pixabay.rose.jpg)
  [[ -z "${PIXABAY_ACCESSKEY:-}" ]] && IO:die "You need valid Pixabay API keys in .env - please create and copy them from https://unsplash.com/oauth/applications"
  image_source="pixabay"
  # shellcheck disable=SC2154
  [[ -z "$input" ]] && IO:die "Need URL or search term to find an Pixabay photo"
  if [[ "$input" == *"://"* ]]; then
    [[ ! "$input" == *"://pixabay.com"* ]] && IO:die "[$input] is not a pixabay.com URL"
    ### Unsplash URL: download one photo
    photo_id=$(basename "${input//-//}")
    # shellcheck disable=SC2154
    [[ -z "${output:-}" ]] && output="pixabay.$photo_id.jpg"
  else
    ### search for terms
    photo_id=$(pixabay:search "$input")
    photo_slug=$(Str:slugify "$input")
    [[ -z "${output:-}" ]] && output="pixabay.$photo_slug.jpg"
  fi
  IO:debug "Output file: [$output]"
  if [[ -n "$photo_id" ]]; then
    IO:debug "Pixabay photo ID = [$photo_id]"
    image_file=$(pixabay:download "$photo_id")
    pixabay:metadata "$photo_id"
    Img:modify "$image_file" "$output"
    IO:print "$output"
  fi
  ;;

file | f)
  #TIP: use «splashmark file» to add texts and effects to a existing image
  #TIP:> splashmark file waterfall.jpg sources/original.jpg
  #TIP:> splashmark --title "Strawberry" -w 1280 -c 640 -e dark,median,grain file sources/original.jpg waterfall.jpg
  image_source="file"
  [[ ! -f "$input" ]] && IO:die "Cannot find input file [$input]"
  IO:debug "Input file : [$input]"
  local name
  local hash
  name=$(basename "$input" .jpg | cut -c1-8)
  hash=$(<<< "$input" Str:digest 6)
  [[ -z "${output:-}" ]] && output="file.$name.$hash.jpg"
  IO:debug "Output file: [$output]"
  Img:modify "$input" "$output"
  IO:print "$output"
  ;;

url | u)
  #TIP: use «splashmark url» to add texts and effects to a image that will be downloaded from a URL
  #TIP:> splashmark file waterfall.jpg "https://i.imgur.com/rbXZcVH.jpg"
  #TIP:> splashmark -w 1280 -c 640 -4 "Photographer: John Doe" -e dark,median,grain url "https://i.imgur.com/rbXZcVH.jpg" waterfall.jpg
  image_source="url"
  IO:debug "Download URL"
  image_file=$(Img:download "$input")
  [[ ! -f "$image_file" ]] && IO:die "Cannot download input image [$input]"
  name=$(basename "$image_file" .jpg | cut -c1-8)
  hash=$(echo "$url" | Str:digest 6)
  [[ -z "${output:-}" ]] && output="url.$name.$hash.jpg"
  IO:debug "Process cached image [$image_file] -> [$output]"
  Img:modify "$image_file" "$output"
  IO:print "$output"
  ;;

sizes)
  Img:list_sizes \
  | awk -F '|' '
  {printf ("%-20s WxH: %4d x %4d\n", $1, $2, $3)}
  '
  ;;

check | env)
  ## leave this default action, it will make it easier to test your script
  #TIP: use «$script_prefix check» to check if this script is ready to execute and what values the options/flags are
  #TIP:> $script_prefix check
  #TIP: use «$script_prefix env» to generate an example .env file
  #TIP:> $script_prefix env > .env
  Script:check
  ;;

*)
  IO:die "action [$action] not recognized"
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

unsplash:api() {
  # $1 = relative API URL
  # $2 = jq query path
  Os:require jq
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
  uniq=$(echo "$full_url" | Str:digest 8)
  # shellcheck disable=SC2154
  local cached="$tmp_dir/unsplash.$uniq.json"
  if [[ ! -f "$cached" ]]; then
    # only get the data once
    IO:debug "Unsplash API = [$show_url]"
    curl -s "$full_url" >"$cached"
    if [[ $(wc <"$cached" -c) -lt 10 ]]; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      IO:alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
      return 1
    fi
    if grep -q "Rate Limit Exceeded" "$cached"; then
      # remove if response is API throttling starts
      rm "$cached"
      IO:alert "API call to [$1] was throttled - remember it's limited to 50 req/hr!"
      return 2
    fi
  else
    IO:debug "API = [$cached]"
  fi
  jq <"$cached" "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

unsplash:metadata() {
  # only get metadata if it was not yet specified as an option
  [[ -z "${photographer:-}" ]] && photographer=$(unsplash:api "/photos/$1" ".user.name")
  [[ -z "${url:-}" ]] && url="$(unsplash:api "/photos/$1" ".links.html")"
  IO:debug "META: Photographer: $photographer"
  IO:debug "META: URL: $url"
}

unsplash:download() {
  # $1 = photo_id
  # returns path of downloaded file
  photo_id=$(basename "/a/$1") # to avoid problems with image ID that start with '-'
  image_url=$(unsplash:api "/photos/$photo_id" .urls.regular)
  # shellcheck disable=SC2154
  cached_image="$tmp_dir/$photo_id.jpg"
  if [[ ! -f "$cached_image" ]]; then
    IO:debug "IMG = [$image_url]"
    curl -s -o "$cached_image" "$image_url"
  else
    IO:debug "IMG = [$cached_image]"
  fi
  [[ ! -f "$cached_image" ]] && IO:die "download [$image_url] failed"
  echo "$cached_image"
}

unsplash:search() {
  # $1 = keyword(s)
  # returns first result
  # shellcheck disable=SC2154
  if [[ "$randomize" -gt 1 ]]; then
    # pick random in 1st N results
    choose_from=$(unsplash:api "/search/photos/?query=$1" .results[].id | wc -l)
    IO:debug "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    IO:debug "PICK: photo $chosen from first $choose_from results"
    unsplash:api "/search/photos/?query=$1" ".results[$chosen].id"
  elif [[ "$number" -gt 1 ]]; then
    # take Nth result
    choose_from=$(unsplash:api "/search/photos/?query=$1" .results[].id | wc -l)
    IO:debug "PICK: $choose_from results in query"
    [[ $choose_from -lt $number ]] && number=$choose_from
    local chosen=$((number - 1))
    IO:debug "PICK: photo $number from results"
    unsplash:api "/search/photos/?query=$1" ".results[$chosen].id"
  else
    # take first photo
    unsplash:api "/search/photos/?query=$1" ".results[0].id"
  fi
}

### Pixabay API stuff

pixabay:api() {
  # $1 = relative API URL
  # $2 = jq query path
  # https://pixabay.com/api/docs/
  # https://pixabay.com/api/?key={ KEY }&q=yellow+flowers&image_type=photo
  Os:require jq
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
  uniq=$(echo "$full_url" | Str:digest 8)
  # shellcheck disable=SC2154
  local cached="$tmp_dir/pixabay.$uniq.json"
  IO:debug "API URL   = [$full_url]"
  IO:debug "API Cache = [$cached]"
  if [[ ! -f "$cached" ]]; then
    # only get the data once
    IO:debug "Pixabay API = [$show_url]"
    curl -s "$full_url" >"$cached"
    if [[ $(wc <"$cached" -c) -lt 10 ]]; then
      # remove if response is too small to be a valid answer
      rm "$cached"
      IO:alert "API call to [$1] came back with empty response - are your Unsplash API keys OK?"
      return 1
    fi
  fi
  jq <"$cached" "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//'
}

pixabay:metadata() {
  # only get metadata if it was not yet specified as an option
  [[ -z "${photographer:-}" ]] && photographer=$(pixabay:api "?id=$photo_id&image_type=photo" ".hits[0].user")
  [[ -z "${url:-}" ]] && url="https://pixabay.com/photos/$photo_id/"
  IO:debug "META: Photographer: $photographer"
  IO:debug "META: URL: $url"
}

pixabay:download() {
  # $1 = photo_id
  # returns path of downloaded file
  # https://pixabay.com/api/?key=<key>&id=<id>+flowers&image_type=photo
  photo_id=$(basename "/a/$1") # to avoid problems with image ID that start with '-'
  image_url=$(pixabay:api "?id=$photo_id&image_type=photo" .hits[0].largeImageURL)
  # shellcheck disable=SC2154
  cached_image="$tmp_dir/$photo_id.jpg"
  if [[ ! -f "$cached_image" ]]; then
    IO:debug "IMG = [$image_url]"
    curl -s -o "$cached_image" "$image_url"
  else
    IO:debug "IMG = [$cached_image]"
  fi
  [[ ! -f "$cached_image" ]] && IO:die "download [$image_url] failed"
  echo "$cached_image"
}

pixabay:search() {
  # $1 = keyword(s)
  # returns first result
  # https://pixabay.com/api/?key={ KEY }&q=yellow+flowers&image_type=photo
  # shellcheck disable=SC2154
  if [[ "$randomize" == 1 ]]; then
    pixabay:api "?image_type=photo&q=$1" ".hits[0].id"
  else
    choose_from=$(pixabay:api "?image_type=photo&q=$1" .hits[].id | wc -l)
    IO:debug "PICK: $choose_from results in query"
    [[ $choose_from -gt $randomize ]] && choose_from=$randomize
    chosen=$((RANDOM % choose_from))
    IO:debug "PICK: photo $chosen from first $choose_from results"
    pixabay:api "?image_type=photo&q=$1" ".hits[$chosen].id"
  fi
}

### Image URL stuff

Img:download() {
  # $1 = url
  local uniq
  local extension="jpg"
  [[ "$1" =~ .png ]] && extension="png"
  [[ "$1" =~ .gif ]] && extension="gif"
  uniq=$(echo "$1" | Str:digest 8)
  # shellcheck disable=SC2154
  local cached_image="$tmp_dir/download.$uniq.$extension"
  if [[ ! -f "$cached_image" ]]; then
    IO:debug "IMG = [$1]"
    curl -s -o "$cached_image" "$1"
  else
    IO:debug "IMG = [$cached_image]"
  fi
  echo "$cached_image"
}

### Modify images

function Img:exif() {
  local filename="$1"
  local exif_key="$2"
  local exif_val="$3"

  if [[ -n "$exif_val" ]]; then
    IO:debug "EXIF: set [$exif_key] to [$exif_val] for [$filename]"
    exiftool -overwrite_original -"$exif_key"="$exif_val" "$filename" >/dev/null 2>/dev/null
  fi
}

function Img:metadata() {
  Os:require exiftool

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
  Img:exif "$2" "Writer-Editor" "https://github.com/pforret/splashmark"
  if [[ "$1" == "unsplash" ]]; then
    ## metadata comes from Unsplash/Pixabay
    if [[ -f "$2" && -n ${photographer} ]]; then
      Img:exif "$2" "Artist" "$photographer"
      Img:exif "$2" "Creator" "$photographer"
      Img:exif "$2" "OwnerID" "$photographer"
      Img:exif "$2" "OwnerName" "$photographer"
      Img:exif "$2" "Credit" "Photo: $photographer on Unsplash.com"
      Img:exif "$2" "ImageDescription" "Photo: $photographer on Unsplash.com"
    fi
  else
    ## metadata, if any, comes from command line options
    if [[ -f "$2" && -n ${photographer} ]]; then
      Img:exif "$2" "Artist" "$photographer"
      Img:exif "$2" "Creator" "$photographer"
      Img:exif "$2" "OwnerID" "$photographer"
      Img:exif "$2" "OwnerName" "$photographer"
      Img:exif "$2" "ImageDescription" "Photo: $photographer"
    fi
  fi
}

function Img:modify() {
  # $1 = input file
  # $2 = output file

  Os:require convert imagemagick
  local font_list

  # shellcheck disable=SC2154
  font_list="$tmp_dir/magick.fonts.txt"
  if [[ ! -f "$font_list" ]]; then
    convert -list font | awk -F: '/Font/ {gsub(" ","",$2); print $2 }' >"$font_list"
  fi
  if [[ -f "$fonttype" ]]; then
    IO:debug "FONT [$fonttype] exists as a font file"
  elif grep -q "$fonttype" "$font_list"; then
    IO:debug "FONT [$fonttype] exists as a standard font"
  elif [[ -f "$script_install_folder/fonts/$fonttype" ]]; then
    fonttype="$script_install_folder/fonts/$fonttype"
    IO:debug "FONT [$fonttype] exists as a splashmark font"
  else
    IO:die "FONT [$fonttype] cannot be found on this system"
  fi
  [[ ! -f "$1" ]] && return 1

  ## scale and crop
  # shellcheck disable=SC2154
  if [[ -n "$preset" ]] ; then
    if [[ $(Img:list_sizes | grep -c "$preset") == 1 ]] ; then
      width="$(Img:list_sizes | grep "$preset" | cut -d'|' -f2)"
      crop="$(Img:list_sizes | grep "$preset" | cut -d'|' -f3)"
      IO:debug "Dimensions are now: $width x $crop ($preset)"
    fi
    # shellcheck disable=SC2154
    if [[ -n "$resize" ]] ; then
      width=$(Tool:calc "$width * $resize")
      crop=$(Tool:calc "$crop * $resize")
      IO:debug "Dimensions are now: $width x $crop (resize x$resize)"
    fi
  fi
  # shellcheck disable=SC2154
  if [[ "$crop" -gt 0 ]]; then
    IO:debug "CROP: image to $width x $crop --> $2"
    convert "$1" -gravity Center -resize "${width}x${crop}^" -crop "${width}x${crop}+0+0" +repage -quality 95% "$2"
  else
    IO:debug "SIZE: to $width wide --> $2"
    convert "$1" -gravity Center -resize "${width}"x -quality 95% "$2"
  fi
  ## set EXIF/IPTC tags
  IO:debug "Img:metadata"
  Img:metadata "$image_source" "$2"

  ## do visual effects
  # shellcheck disable=SC2154
  if [[ -n "$effect" ]]; then
    IO:debug "Img:effect"
  # shellcheck disable=SC2154
    Img:effect "$2" "$effect"
  fi
  ## add small watermarks in the corners
  # shellcheck disable=SC2154
  [[ -n "$northwest" ]] && Img:watermark "$2" NorthWest "$northwest"
  # shellcheck disable=SC2154
  [[ -n "$northeast" ]] && Img:watermark "$2" NorthEast "$northeast"
  # shellcheck disable=SC2154
  [[ -n "$southwest" ]] && Img:watermark "$2" SouthWest "$southwest"
  # shellcheck disable=SC2154
  [[ -n "$southeast" ]] && Img:watermark "$2" SouthEast "$southeast"

  ## add large title watermarks in the middle
  # shellcheck disable=SC2154
  [[ -n "$title" || -n "$subtitle" ]] && Img:title "$2"
}

function text_resolve() {
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

function rescale_weight(){
  local percent="$1"
  local percent0="$2"
  local percent100="$3"
  local rescaled
  if [[ "${4:-int}" == "float" ]] ; then
    rescaled=$(awk "BEGIN {print $percent0 + ( $percent100 - $percent0 ) * $percent / 100 }")
  else
    rescaled=$(( percent0 + ( percent100 - percent0 ) * percent / 100 ))
  fi
  IO:debug "Rescaled: $percent => $rescaled"
  echo "$rescaled"
}

function Img:effect() {
  # $1 = image path
  # $2 = effect name
  # shellcheck disable=SC2154
  [[ ! -f "$1" ]] && return 1
  Os:require mogrify imagemagick
  local weight
  local shrink
  local percent
  local large
  local expand

  # shellcheck disable=SC2154
  for fx1 in $(echo "$2" | tr ',' "\n"); do
    IO:debug "Effect : $fx1"
    # shellcheck disable=SC2001
    percent="$(echo "$fx1" | sed 's/[^0-9]//g')"
    percent="${percent:-20}"
    IO:debug "Weight : $percent %"
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

function Img:watermark() {
  # $1 = image path
  # $2 = gravity
  # $3 = text

  [[ ! -f "$1" ]] && return 1
  Os:require mogrify imagemagick

  IO:debug "Img:watermark $3"
  # shellcheck disable=SC2154
  char1=$(Str:upper "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008"
    ;;
  *)
    shadow_color="FFF8"
    ;;
  esac
  text=$(text_resolve "$3")

  IO:debug "MARK: [$text] in $2 corner ..."
  # shellcheck disable=SC2154
  local margin2=$((margin + 1))
  # shellcheck disable=SC2154
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$fontcolor" -annotate "0x0+${margin}+${margin}" "$text" "$1"
}

function choose_position() {
  position="$1"
  # shellcheck disable=SC2154
  case ${gravity,,} in
  left | west) position="${position}West" ;;
  right | east) position="${position}East" ;;
  esac
  [[ -z "$position" ]] && position="Center"
  echo "$position"
}

function Img:title() {
  # $1 = image path

  [[ ! -f "$1" ]] && return 1
  # shellcheck disable=SC2154
  char1=$(Str:upper "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F)
    shadow_color="0008"
    ;;
  *)
    shadow_color="FFF8"
    ;;
  esac
  # shellcheck disable=SC2154
  local margin1=$((margin * 3))
  local margin2=$((margin1 + 1))
  if [[ -n "$title" ]]; then
    text=$(text_resolve "$title")
    position=""
    [[ -n "$subtitle" ]] && position="North"
    position=$(choose_position "$position")
    IO:debug "MARK: title [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(Str:lower "$gravity") == "center" ]]; then
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
    IO:debug "MARK: subtitle [$text] in $position ..."
    # shellcheck disable=SC2154
    if [[ $(Str:lower "$gravity") == "center" ]]; then
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+1+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor" -annotate "0x0+0+${margin1}" "$text" "$1"
    else
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$shadow_color" -annotate "0x0+${margin2}+${margin2}" "$text" "$1"
      mogrify -gravity "$position" -font "$fonttype" -pointsize "$subtitlesize" -fill "#$fontcolor" -annotate "0x0+${margin1}+${margin1}" "$text" "$1"
    fi
  fi
}

function Img:list_sizes(){
  cat <<END
cinema:flat|1998|1080
cinema:hd|1920|1080
cinema:scope|2048|858
facebook:cover|851|315
facebook:horizontal|1200|630
facebook:story|1080|1920
facebook:vertical|1080|1350
github:repo|1280|640
instagram:horizontal|1350|1080
instagram:square|1080|1080
instagram:story|1080|1920
instagram:vertical|1080|1350
linkedin:horizontal|1104|736
medium:horizontal|1500|1200
pinterest:vertical|1000|1500
tumblr:vertical|1280|1920
twitter:header|1500|500
twitter:post|1024|512
END
}
#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################
#####################################################################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
force=0
help=0
error_prefix=""

#to enable verbose even before option parsing
verbose=0
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1

#to enable quiet even before option parsing
quiet=0
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

### stdIO:print/stderr output
function IO:initialize() {
  [[ "${BASH_SOURCE[0]:-}" != "${0}" ]] && sourced=1 || sourced=0
  [[ -t 1 ]] && piped=0 || piped=1 # detect if output is piped
  if [[ $piped -eq 0 ]]; then
    txtReset=$(tput sgr0)
    txtError=$(tput setaf 160)
    txtInfo=$(tput setaf 2)
    txtWarn=$(tput setaf 214)
    txtBold=$(tput bold)
    txtItalic=$(tput sitm)
    txtUnderline=$(tput smul)
  else
    txtReset=""
    txtError=""
    txtInfo=""
    txtInfo=""
    txtWarn=""
    txtBold=""
    txtItalic=""
    txtUnderline=""
  fi

  [[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported
  if [[ $unicode -gt 0 ]]; then
    char_succes="✅"
    char_fail="⛔"
    char_alert="✴️"
    char_wait="⏳"
    info_icon="🌼"
    config_icon="🌱"
    clean_icon="🧽"
    require_icon="🔌"
  else
    char_succes="OK "
    char_fail="!! "
    char_alert="?? "
    char_wait="..."
    info_icon="(i)"
    config_icon="[c]"
    clean_icon="[c]"
    require_icon="[r]"
  fi
  error_prefix="${txtError}>${txtReset}"
}

function IO:print() {
  ((quiet)) && true || printf '%b\n' "$*"
}

function IO:debug() {
  ((verbose)) && IO:print "${txtInfo}# $* ${txtReset}" >&2
  true
}

function IO:die() {
  IO:print "${txtError}${char_fail} $script_basename${txtReset}: $*" >&2
  tput bel
  Script:exit
}

function IO:alert() {
  IO:print "${txtWarn}${char_alert}${txtReset}: ${txtUnderline}$*${txtReset}" >&2
}

function IO:success() {
  IO:print "${txtInfo}${char_succes}${txtReset}  ${txtBold}$*${txtReset}"
}

function IO:announce() {
  IO:print "${txtInfo}${char_wait}${txtReset}  ${txtItalic}$*${txtReset}"
  sleep 1
}

function IO:progress() {
  ((quiet)) || (
    local screen_width
    screen_width=$(tput cols 2>/dev/null || echo 80)
    local rest_of_line
    rest_of_line=$((screen_width - 5))

    if ((piped)); then
      IO:print "... $*" >&2
    else
      printf "... %-${rest_of_line}b\r" "$*                                             " >&2
    fi
  )
}

### interactive
function IO:confirm() {
  ((force)) && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

function IO:question() {
  local ANSWER
  local DEFAULT=${2:-}
  read -r -p "$1 ($DEFAULT) > " ANSWER
  [[ -z "$ANSWER" ]] && echo "$DEFAULT" || echo "$ANSWER"
}

function IO:log() {
  [[ -n "${log_file:-}" ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"
}

function Tool:calc() {
  awk "BEGIN {print $*} ; "
}

function Tool:time() {
  if [[ $(command -v perl) ]]; then
    perl -MTime::HiRes=time -e 'printf "%.3f\n", time'
  elif [[ $(command -v php) ]]; then
    php -r 'echo microtime(true) . "\n"; '
  elif [[ $(command -v python) ]]; then
    python -c "import time; print(time.time()) "
  else
    date "+%s" | awk '{printf("%.3f\n",$1)}'
  fi
}

### string processing

function Str:trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

function Str:lower() {
  if [[ -n "$1" ]]; then
    local input="$*"
    echo "${input,,}"
  else
    awk '{print tolower($0)}'
  fi
}

function Str:upper() {
  if [[ -n "$1" ]]; then
    local input="$*"
    echo "${input^^}"
  else
    awk '{print toupper($0)}'
  fi
}

function Str:ascii() {
  # remove all characters with accents/diacritics to latin alphabet
  # shellcheck disable=SC2020
  sed 'y/àáâäæãåāǎçćčèéêëēėęěîïííīįìǐłñńôöòóœøōǒõßśšûüǔùǖǘǚǜúūÿžźżÀÁÂÄÆÃÅĀǍÇĆČÈÉÊËĒĖĘĚÎÏÍÍĪĮÌǏŁÑŃÔÖÒÓŒØŌǑÕẞŚŠÛÜǓÙǕǗǙǛÚŪŸŽŹŻ/aaaaaaaaaccceeeeeeeeiiiiiiiilnnooooooooosssuuuuuuuuuuyzzzAAAAAAAAACCCEEEEEEEEIIIIIIIILNNOOOOOOOOOSSSUUUUUUUUUUYZZZ/'
}

function Str:slugify() {
  # Str:Str:slugify <input> <separator>
  # Str:Str:slugify "Jack, Jill & Clémence LTD"      => jack-jill-clemence-ltd
  # Str:Str:slugify "Jack, Jill & Clémence LTD" "_"  => jack_jill_clemence_ltd
  separator="${2:-}"
  [[ -z "$separator" ]] && separator="-"
  Str:lower "$1" |
    Str:ascii |
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

function Str:title() {
  # Str:title <input> <separator>
  # Str:title "Jack, Jill & Clémence LTD"     => JackJillClemenceLtd
  # Str:title "Jack, Jill & Clémence LTD" "_" => Jack_Jill_Clemence_Ltd
  separator="${2:-}"
  # shellcheck disable=SC2020
  Str:lower "$1" |
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

function Str:digest() {
  local length=${1:-6}
  if [[ -n $(command -v md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

trap "IO:die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for

Script:exit() {
  for temp_file in "${temp_files[@]}"; do
    [[ -f "$temp_file" ]] && (
      IO:debug "Delete temp file [$temp_file]"
      rm -f "$temp_file"
    )
  done
  trap - INT TERM EXIT
  IO:debug "$script_basename finished after $SECONDS seconds"
  exit 0
}

Script:check_version() {
  (
    # shellcheck disable=SC2164
    pushd "$script_install_folder" &>/dev/null
    if [[ -d .git ]]; then
      local remote
      remote="$(git remote -v | grep fetch | awk 'NR == 1 {print $2}')"
      IO:progress "Check for latest version - $remote"
      git remote update &>/dev/null
      if [[ $(git rev-list --count "HEAD...HEAD@{upstream}" 2>/dev/null) -gt 0 ]]; then
        IO:print "There is a more recent update of this script - run <<$script_prefix update>> to update"
      fi
    fi
    # shellcheck disable=SC2164
    popd &>/dev/null
  )
}

Script:git_pull() {
  # run in background to avoid problems with modifying a running interpreted script
  (
    sleep 1
    cd "$script_install_folder" && git pull
  ) &
}

Script:show_tips() {
  ((sourced)) && return 0
  # shellcheck disable=SC2016
  grep <"${BASH_SOURCE[0]}" -v '$0' |
    awk \
      -v green="$txtInfo" \
      -v yellow="$txtWarn" \
      -v reset="$txtReset" \
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

Script:check() {
  local name
  if [[ -n $(Option:filter flag) ]]; then
    IO:print "## ${txtInfo}boolean flags${txtReset}:"
    Option:filter flag |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    IO:print " "
    IO:print " "
  fi

  if [[ -n $(Option:filter option) ]]; then
    IO:print "## ${txtInfo}option defaults${txtReset}:"
    Option:filter option |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=\$${name:-}\""
        else
          eval "echo -n \"$name=\$${name:-}  \""
        fi
      done
    IO:print " "
    IO:print " "
  fi

  if [[ -n $(Option:filter list) ]]; then
    IO:print "## ${txtInfo}list options${txtReset}:"
    Option:filter list |
      while read -r name; do
        if ((piped)); then
          eval "echo \"$name=(\${${name}[@]})\""
        else
          eval "echo -n \"$name=(\${${name}[@]})  \""
        fi
      done
    IO:print " "
    IO:print " "
  fi

  if [[ -n $(Option:filter param) ]]; then
    if ((piped)); then
      IO:debug "Skip parameters for .env files"
    else
      IO:print "## ${txtInfo}parameters${txtReset}:"
      Option:filter param |
        while read -r name; do
          # shellcheck disable=SC2015
          ((piped)) && eval "echo \"$name=\\\"\${$name:-}\\\"\"" || eval "echo -n \"$name=\\\"\${$name:-}\\\"  \""
        done
      echo " "
    fi
    IO:print " "
  fi

  if [[ -n $(Option:filter choice) ]]; then
    if ((piped)); then
      IO:debug "Skip choices for .env files"
    else
      IO:print "## ${txtInfo}choice${txtReset}:"
      Option:filter choice |
        while read -r name; do
          # shellcheck disable=SC2015
          ((piped)) && eval "echo \"$name=\\\"\${$name:-}\\\"\"" || eval "echo -n \"$name=\\\"\${$name:-}\\\"  \""
        done
      echo " "
    fi
    IO:print " "
  fi

  IO:print "## ${txtInfo}required commands${txtReset}:"
  Script:show_required
}

Option:usage() {
  IO:print "Program : ${txtInfo}$script_basename${txtReset}  by ${txtWarn}$script_author${txtReset}"
  IO:print "Version : ${txtInfo}v$script_version${txtReset} (${txtWarn}$script_modified${txtReset})"
  IO:print "Purpose : ${txtInfo}$script_description${txtReset}"
  echo -n "Usage   : $script_basename"
  Option:config |
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
  $1 ~ /choice/ {
        fulltext = fulltext sprintf("\n    %-17s: [choice] %s","<"$3">",$4);
        if($5!=""){fulltext = fulltext "  [options: " $5 "]"; }
        oneline  = oneline " <" $3 ">"
    }
    END {print oneline; print fulltext}
  '
}

function Option:filter() {
  Option:config | grep "$1|" | cut -d'|' -f3 | sort | grep -v '^\s*$'
}

function Script:show_required() {
  grep 'Os:require' "$script_install_path" |
    grep -v -E '\(\)|grep|# Os:require' |
    awk -v install="# $install_package " '
    function ltrim(s) { sub(/^[ "\t\r\n]+/, "", s); return s }
    function rtrim(s) { sub(/[ "\t\r\n]+$/, "", s); return s }
    function trim(s) { return rtrim(ltrim(s)); }
    NF == 2 {print install trim($2); }
    NF == 3 {print install trim($3); }
    NF > 3  {$1=""; $2=""; $0=trim($0); print "# " trim($0);}
  ' |
    sort -u
}

function Option:initialize() {
  local init_command
  init_command=$(Option:config |
    grep -v "verbose|" |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /choice/   {print $3 "=\"\"; "}
    $1 ~ /list/     {print $3 "=(); "}
    $1 ~ /secret/   {print $3 "=\"\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    eval "$init_command"
  fi
}

function Option:has_single() { Option:config | grep 'param|1|' >/dev/null; }
function Option:has_choice() { Option:config | grep 'choice|1' >/dev/null; }
function Option:has_optional() { Option:config | grep 'param|?|' >/dev/null; }
function Option:has_multi() { Option:config | grep 'param|n|' >/dev/null; }

function Option:parse() {
  if [[ $# -eq 0 ]]; then
    Option:usage >&2
    Script:exit
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
    save_option=$(Option:config |
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
        IO:debug "$config_icon parameter: ${save_var}=$2"
      else
        IO:debug "$config_icon flag: $save_option"
      fi
      eval "$save_option"
    else
      IO:die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    Option:usage
    Script:check_version
    IO:print "                                  "
    echo "### TIPS & EXAMPLES"
    Script:show_tips

  ) && Script:exit

  local option_list
  local option_count
  local choices
  local single_params
  ## then run through the given parameters
  if Option:has_choice; then
    choices=$(Option:config | awk -F"|" '
      $1 == "choice" && $2 == 1 {print $3}
      ')
    option_list=$(xargs <<<"$choices")
    option_count=$(wc <<<"$choices" -w | xargs)
    IO:debug "$config_icon Expect : $option_count choice(s): $option_list"
    [[ $# -eq 0 ]] && IO:die "need the choice(s) [$option_list]"

    local choices_list
    local valid_choice
    for param in $choices; do
      [[ $# -eq 0 ]] && IO:die "need choice [$param]"
      [[ -z "$1" ]] && IO:die "need choice [$param]"
      IO:debug "$config_icon Assign : $param=$1"
      # check if choice is in list
      choices_list=$(Option:config | awk -F"|" -v choice="$param" '$1 == "choice" && $3 = choice {print $5}')
      valid_choice=$(tr <<<"$choices_list" "," "\n" | grep "$1")
      [[ -z "$valid_choice" ]] && IO:die "choice [$1] is not valid, should be in list [$choices_list]"

      eval "$param=\"$1\""
      shift
    done
  else
    IO:debug "$config_icon No choices to process"
    choices=""
    option_count=0
  fi

  if Option:has_single; then
    single_params=$(Option:config | awk -F"|" '
      $1 == "param" && $2 == 1 {print $3}
      ')
    option_list=$(xargs <<<"$single_params")
    option_count=$(wc <<<"$single_params" -w | xargs)
    IO:debug "$config_icon Expect : $option_count single parameter(s): $option_list"
    [[ $# -eq 0 ]] && IO:die "need the parameter(s) [$option_list]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && IO:die "need parameter [$param]"
      [[ -z "$1" ]] && IO:die "need parameter [$param]"
      IO:debug "$config_icon Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    IO:debug "$config_icon No single params to process"
    single_params=""
    option_count=0
  fi

  if Option:has_optional; then
    local optional_params
    local optional_count
    optional_params=$(Option:config | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(wc <<<"$optional_params" -w | xargs)
    IO:debug "$config_icon Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params; do
      IO:debug "$config_icon Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    IO:debug "$config_icon No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if Option:has_multi; then
    #IO:debug "Process: multi param"
    local multi_count
    local multi_param
    multi_count=$(Option:config | grep -c 'param|n|')
    multi_param=$(Option:config | grep 'param|n|' | cut -d'|' -f3)
    IO:debug "$config_icon Expect : $multi_count multi parameter: $multi_param"
    ((multi_count > 1)) && IO:die "cannot have >1 'multi' parameter: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && IO:die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      IO:debug "$config_icon Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && IO:die "cannot interpret extra parameters"
  fi
}

function Os:require() {
  local install_instructions
  local binary
  local words
  local path_binary
  # $1 = binary that is required
  binary="$1"
  path_binary=$(command -v "$binary" 2>/dev/null)
  [[ -n "$path_binary" ]] && IO:debug "️$require_icon required [$binary] -> $path_binary" && return 0
  # $2 = how to install it
  words=$(echo "${2:-}" | wc -w)
  if ((force)); then
    IO:announce "Installing [$1] ..."
    case $words in
    0) eval "$install_package $1" ;;
      # Os:require ffmpeg -- binary and package have the same name
    1) eval "$install_package $2" ;;
      # Os:require convert imagemagick -- binary and package have different names
    *) eval "${2:-}" ;;
      # Os:require primitive "go get -u github.com/fogleman/primitive" -- non-standard package manager
    esac
  else
    install_instructions="$install_package $1"
    [[ $words -eq 1 ]] && install_instructions="$install_package $2"
    [[ $words -gt 1 ]] && install_instructions="${2:-}"

    IO:alert "$script_basename needs [$binary] but it cannot be found"
    IO:alert "1) install package  : $install_instructions"
    IO:alert "2) check path       : export PATH=\"[path of your binary]:\$PATH\""
    IO:die "Missing program/script [$binary]"
  fi
}

function Os:folder() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      IO:debug "$clean_icon Create folder : [$folder]"
      mkdir -p "$folder"
    else
      IO:debug "$clean_icon Cleanup folder: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

function Os:follow_link() {
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
  IO:debug "$info_icon Symbolic ln: $1 -> [$symlink]"
  Os:follow_link "$link_folder/$link_name"
}

function Os:notify() {
  # cf https://levelup.gitconnected.com/5-modern-bash-scripting-techniques-that-only-a-few-programmers-know-4abb58ddadad
  local message="$1"
  local source="${2:-$script_basename}"

  [[ -n $(command -v notify-send) ]] && notify-send "$source" "$message"                                      # for Linux
  [[ -n $(command -v osascript) ]] && osascript -e "display notification \"$message\" with title \"$source\"" # for MacOS
}

function Os:busy() {
  # show spinner as long as process $pid is running
  local pid="$1"
  local message="${2:-}"
  local frames=("|" "/" "-" "\\")
  (
    while kill -0 "$pid" &>/dev/null; do
      for frame in "${frames[@]}"; do
        printf "\r[ $frame ] %s..." "$message"
        sleep 0.5
      done
    done
    printf "\n"
  )
}

function Os:beep() {
  local type="${1=-info}"
  case $type in
  *)
    tput bel
    ;;
  esac
}

function Script:meta() {
  local git_repo_remote=""
  local git_repo_root=""
  local os_kernel=""
  local os_machine=""
  local os_name=""
  local os_version=""
  local script_hash="?"
  local script_lines="?"
  local shell_brand=""
  local shell_version=""

  script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  script_basename=$(basename "${BASH_SOURCE[0]}")
  execution_day=$(date "+%Y-%m-%d")

  script_install_path="${BASH_SOURCE[0]}"
  IO:debug "$info_icon Script path: $script_install_path"
  script_install_path=$(Os:follow_link "$script_install_path")
  IO:debug "$info_icon Linked path: $script_install_path"
  script_install_folder="$(cd -P "$(dirname "$script_install_path")" && pwd)"
  IO:debug "$info_icon In folder  : $script_install_folder"
  if [[ -f "$script_install_path" ]]; then
    script_hash=$(Str:digest <"$script_install_path" 8)
    script_lines=$(awk <"$script_install_path" 'END {print NR}')
  fi

  # get shell/operating system/versions
  shell_brand="sh"
  shell_version="?"
  [[ -n "${ZSH_VERSION:-}" ]] && shell_brand="zsh" && shell_version="$ZSH_VERSION"
  [[ -n "${BASH_VERSION:-}" ]] && shell_brand="bash" && shell_version="$BASH_VERSION"
  [[ -n "${FISH_VERSION:-}" ]] && shell_brand="fish" && shell_version="$FISH_VERSION"
  [[ -n "${KSH_VERSION:-}" ]] && shell_brand="ksh" && shell_version="$KSH_VERSION"
  IO:debug "$info_icon Shell type : $shell_brand - version $shell_version"

  os_kernel=$(uname -s)
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
      os_name=$(lsb_release -i | awk -F: '{$1=""; gsub(/^[\s\t]+/,"",$2); gsub(/[\s\t]+$/,"",$2); print $2}')    # Ubuntu/Raspbian
      os_version=$(lsb_release -r | awk -F: '{$1=""; gsub(/^[\s\t]+/,"",$2); gsub(/[\s\t]+$/,"",$2); print $2}') # 20.04
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
  IO:debug "$info_icon System OS  : $os_name ($os_kernel) $os_version on $os_machine"
  IO:debug "$info_icon Package mgt: $install_package"

  # get last modified date of this script
  script_modified="??"
  [[ "$os_kernel" == "Linux" ]] && script_modified=$(stat -c %y "$script_install_path" 2>/dev/null | cut -c1-16) # generic linux
  [[ "$os_kernel" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$script_install_path" 2>/dev/null)          # for MacOS

  IO:debug "$info_icon Version  : $script_version"
  IO:debug "$info_icon Created  : $script_created"
  IO:debug "$info_icon Modified : $script_modified"

  IO:debug "$info_icon Lines    : $script_lines lines / md5: $script_hash"
  IO:debug "$info_icon User     : $USER@$HOSTNAME"

  # if run inside a git repo, detect for which remote repo it is
  if git status &>/dev/null; then
    git_repo_remote=$(git remote -v | awk '/(fetch)/ {print $2}')
    IO:debug "$info_icon git remote : $git_repo_remote"
    git_repo_root=$(git rev-parse --show-toplevel)
    IO:debug "$info_icon git folder : $git_repo_root"
  fi

  # get script version from VERSION.md file - which is automatically updated by pforret/setver
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  # get script version from git tag file - which is automatically updated by pforret/setver
  [[ -n "$git_repo_root" ]] && [[ -n "$(git tag &>/dev/null)" ]] && script_version=$(git tag --sort=version:refname | tail -1)
}

function Script:initialize() {
  log_file=""
  if [[ -n "${tmp_dir:-}" ]]; then
    # clean up TMP folder after 1 day
    Os:folder "$tmp_dir" 1
  fi
  if [[ -n "${log_dir:-}" ]]; then
    Os:folder "$log_dir" 30
    log_file="$log_dir/$script_prefix.$execution_day.log"
    IO:debug "$config_icon log_file: $log_file"
  fi
}

function Os:tempfile() {
  local extension=${1:-txt}
  local file="${tmp_dir:-/tmp}/$execution_day.$RANDOM.$extension"
  IO:debug "$config_icon tmp_file: $file"
  temp_files+=("$file")
  echo "$file"
}

function Os:import_env() {
  local env_files
  env_files=(
    "$script_install_folder/.env"
    "$script_install_folder/.$script_prefix.env"
    "$script_install_folder/$script_prefix.env"
    "./.env"
    "./.$script_prefix.env"
    "./$script_prefix.env"
  )

  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      IO:debug "$config_icon Read  dotenv: [$env_file]"
      local clean_file
      clean_file=$(Os:clean_env "$env_file")
      # shellcheck disable=SC1090
      source "$clean_file" && rm "$clean_file"
    fi
  done
}

function Os:clean_env() {
  local input="$1"
  local output="$1.__.sh"
  [[ ! -f "$input" ]] && IO:die "Input file [$input] does not exist"
  IO:debug "$clean_icon Clean dotenv: [$output]"
  awk <"$input" '
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
      /=/ { # skip lines with no equation
        $0=trim($0);
        if(substr($0,1,1) != "#"){ # skip comments
          equal=index($0, "=");
          key=trim(substr($0,1,equal-1));
          val=trim(substr($0,equal+1));
          if(match(val,/^".*"$/) || match(val,/^\047.*\047$/)){
            print key "=" val
          } else {
            print key "=\"" val "\""
          }
        }
      }
  ' >"$output"
  echo "$output"
}

IO:initialize # output settings
Script:meta   # find installation folder

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && IO:die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && IO:die "user is $USER, CANNOT be root to run [$script_basename]"

Option:initialize # set default values for flags & options
Os:import_env     # overwrite with .env if any

if [[ $sourced -eq 0 ]]; then
  Option:parse "$@" # overwrite with specified options if any
  Script:initialize # clean up folders
  Script:main       # run Script:main program
  Script:exit       # exit and clean up
else
  # just disable the trap, don't execute Script:main
  trap - INT TERM EXIT
fi
