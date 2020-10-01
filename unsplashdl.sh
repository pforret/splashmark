#!/usr/bin/env bash
### ==============================================================================
### SO HOW DO YOU PROCEED WITH YOUR SCRIPT?
### 1. define the options/parameters and defaults you need in list_options()
### 2. implement the different actions in main() with helper functions
### 3. implement helper functions you defined in previous step
### 4. add binaries your script needs (e.g. ffmpeg, jq) to verify_programs
### ==============================================================================

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
option|l|log_dir|folder for log files |log
option|t|tmp_dir|folder for temp files|.tmp
option|w|width|image width for resizing|1080
option|c|height|image height for cropping|0
option|p|fonttype|font type family to use|Courier-Bold
option|q|fontsize|font size to use|15
option|r|fontcolor|font color to use|FFFFFF
option|1|northwest|text to put in left top|
option|2|northeast|text to put in right top|{url}
option|3|southwest|text to put in left bottom|
option|4|southeast|text to put in right bottom|{copyright2}
param|1|action|action to perform: download/search
# there can only be 1 param|n and it should be the last
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
  # add programs you need in your script here, like tar, wget, ffmpeg, rsync ...
  verify_programs awk basename cut date dirname find grep head mkdir sed stat tput uname wc exiftool convert
  prep_log_and_temp_dir

  action=$(lower_case "$action")
  case $action in
  download | d)
    # shellcheck disable=SC2154
    photo_id=$(basename "$input")
    if [[ -n "$photo_id" ]]; then
      log "Found photo ID = $photo_id"
      image_file=$(unsplash_download "$photo_id")
      unsplash_metadata "$photo_id"
      # shellcheck disable=SC2154
      image_prepare "$image_file" "$output"
      out "$output"
    fi
    ;;

  search | s)
    photo_id=$(unsplash_search "$input")
    if [[ -n "$photo_id" ]]; then
      log "Found photo ID = $photo_id"
      image_file=$(unsplash_download "$photo_id")
      unsplash_metadata "$photo_id"
      image_prepare "$image_file" "$output"
      out "$output"
    fi
    ;;

  *)
    die "action [$action] not recognized"
    ;;
  esac
}

#####################################################################
## Put your helper scripts here
#####################################################################

unsplash_api() {
  # $1 = relative API URL
  # $2 = jq query path
  api_endpoint="https://api.unsplash.com"
  full_url="$api_endpoint$1"
  if [[ -z "${UNSPLASH_ACCESSKEY:-}" ]] ; then
    die "You need Unsplash API keys -  please create and copy them from https://unsplash.com/oauth/applications"
  fi
  if [[ $full_url =~ "?" ]]; then
    # already has querystring
    full_url="$full_url&client_id=$UNSPLASH_ACCESSKEY"
  else
    # no querystring yet
    full_url="$full_url?client_id=$UNSPLASH_ACCESSKEY"
  fi
  uniq=$(echo "$full_url" | hash 8)
  # shellcheck disable=SC2154
  cached="$tmp_dir/unsplash.$uniq.json"
  log "Cache [$cached]"
  if [[ ! -f "$cached" ]] || grep -c '{' "$cached" >/dev/null; then
    # only the data once
    log "URL = [$full_url]"
    curl -s "$full_url" >"$cached"
  fi
  jq <"$cached" "${2:-.}" |
    sed 's/"//g' |
    sed 's/,$//' |
    tee "$tmp_dir/query.$uniq$2.txt"
}

unsplash_metadata() {
  photographer=$(unsplash_api "/photos/$1" ".user.name")
  url=$(unsplash_api "/photos/$1" ".links.html")
  log "Photographer = [$photographer]"
}

unsplash_download() {
  # $1 = photo_id
  # returns path of downloaded file
  photo_id=$(basename "$1")
  image_url=$(unsplash_api "/photos/$photo_id" .urls.regular)
  log "Download = [$image_url]"
  from_unsplash="$tmp_dir/$photo_id.jpg"
  log "Original file = [$from_unsplash]"
  if [[ ! -f "$from_unsplash" ]]; then
    curl -s -o "$from_unsplash" "$image_url"
    [[ ! -f "$from_unsplash" ]] && die "download [$image_url] failed"
  fi
  echo "$from_unsplash"
}

unsplash_search() {
  # $1 = keyword(s)
  # returns first result
  unsplash_api "/search/photos/?query=$1" ".results[0].id"
}

set_exif() {
  filename="$1"
  exif_key="$2"
  exif_val="$3"

  if [[ -n "$exif_val" ]]; then
    log "EXIF: set [$exif_key] to [$exif_val] for [$filename]"
    exiftool -overwrite_original -"$exif_key"="$exif_val" "$filename" >/dev/null
  fi
}

image_prepare() {
  # $1 = input file
  # $2 = output file

  # shellcheck disable=SC2154
  if [[ $height -gt 0 ]]; then
    log "Resize & crop image to $width x $height --> $2"
    convert "$1" -gravity Center -resize "${width}"x -crop "${width}x${height}+0+0" +repage "$2"
  else
    log "Resize image to $width wide --> $2"
    convert "$1" -gravity Center -resize "${width}"x "$2"
  fi
  if [[ -f "$2" ]]; then
    set_exif "$2" "Artist" "$photographer"
    set_exif "$2" "OwnerName" "$photographer"
    set_exif "$2" "Credit" "unsplash.com"
    set_exif "$2" "ImageDescription" "Photo: $photographer on Unsplash.com"
  fi
  [[ -n "$northwest" ]] && image_watermark "$2" NorthWest "$northwest"
  [[ -n "$northeast" ]] && image_watermark "$2" NorthEast "$northeast"
  [[ -n "$southwest" ]] && image_watermark "$2" SouthWest "$southwest"
  [[ -n "$southeast" ]] && image_watermark "$2" SouthEast "$southeast"
}

text_resolve() {
  echo "$1" \
  | sed "s|{copyright}|Photo by {photographer} on Unsplash.com|" \
  | sed "s|{copyright2}|© {photographer} » Unsplash.com|" \
  | sed "s|{photographer}|$photographer|" \
  | sed "s|{url}|$url|"
}

image_watermark() {
  # $1 = image path
  # $2 = gravity
  # $3 = text

  # magick mogrify -gravity "SouthWest" -pointsize "$largetext" -font "$font" -fill "#0008" -annotate "0x0+22+22" "$title" "$output_file"
  # shellcheck disable=SC2154
  char1=$(upper_case "${fontcolor:0:1}")
  case $char1 in
  9 | A | B | C | D | E | F) fontbg="000000" ;;
  default) fontbg="FFFFFF" ;;
  esac
  text=$(text_resolve "$3")

  log "Set text [$text] in $2 corner ..."
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$fontbg" -annotate "0x0+21+21" "$text" "$1"
  mogrify -gravity "$2" -font "$fonttype" -pointsize "$fontsize" -fill "#$fontcolor" -annotate "0x0+20+20" "$text" "$1"
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
#TIP: use «hash» to create short unique values of fixed length based on longer inputs
#TIP:> url_contents="$domain.$(echo $url | hash 8).html"

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
#TIP: use «out» to show any kind of output, except when option --quiet is specified
#TIP:> out "User is [$USER]"

progress() {
  ((quiet)) || (
    ((piped)) && out "$*" || printf "... %-${wprogress}b\r" "$*                                             "
  )
}
#TIP: use «progress» to show one line of progress that will be overwritten by the next output
#TIP:> progress "Now generating file $nb of $total ..."

die() {
  tput bel
  out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2
  safe_exit
}
fail() {
  tput bel
  out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2
  safe_exit
}
#TIP: use «die» to show error message and exit program
#TIP:> if [[ ! -f $output ]] ; then ; die "could not create output" ; fi

alert() { out "${col_red}${char_alrt}${col_reset}: $*" >&2; } # print error and continue
#TIP: use «alert» to show alert/warning message but continue
#TIP:> if [[ ! -f $output ]] ; then ; alert "could not create output" ; fi

success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
#TIP: use «success» to show success message but continue
#TIP:> if [[ -f $output ]] ; then ; success "output was created!" ; fi

announce() {
  out "${col_grn}${char_wait}${col_reset}  $*"
  sleep 1
}
#TIP: use «announce» to show the start of a task
#TIP:> announce "now generating the reports"

log() { ((verbose)) && out "${col_ylw}# $* ${col_reset}" >&2; }
#TIP: use «log» to show information that will only be visible when -v is specified
#TIP:> log "input file: [$inputname] - [$inputsize] MB"

lower_case() { echo "$*" | awk '{print tolower($0)}'; }
upper_case() { echo "$*" | awk '{print toupper($0)}'; }
#TIP: use «lower_case» and «upper_case» to convert to upper/lower case
#TIP:> param=$(lower_case $param)

confirm() {
  is_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}
#TIP: use «confirm» for interactive confirmation before doing something
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi

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
#TIP: use «ask» for interactive setting of variables
#TIP:> ask NAME "What is your name" "Peter"

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
#TIP: use «is_empty» and «is_not_empty» to test for variables
#TIP:> if is_empty "$email" ; then ; echo "Need Email!" ; fi

is_file() { [[ -f "$1" ]]; }
is_dir() { [[ -d "$1" ]]; }
#TIP: use «is_file» and «is_dir» to test for files or folders
#TIP:> if is_file "/etc/hosts" ; then ; cat "/etc/hosts" ; fi

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
#TIP: use «folder_prep» to create a folder if needed and otherwise clean up old files
#TIP:> folder_prep "$log_dir" 7 # delete all files olders than 7 days

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
    echo "### SCRIPT AUTHORING TIPS"
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
  if git status >/dev/null; then
    readonly in_git_repo=1
  else
    # shellcheck disable=SC2034
    readonly in_git_repo=0
  fi
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
  #TIP: use «.env» file in script folder / current folder to set secrets or common config settings
  #TIP:> AWS_SECRET_ACCESS_KEY="..."

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
