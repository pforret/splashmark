#!/usr/bin/env bash

folder=$(dirname "$0")
cd "$folder" || exit
if [[ ! $(command -v splashmark) ]] ; then
  echo "### WARNING"
  echo "Requires pforret/splashmark"
  echo "Follow instructions on https://github.com/pforret/splashmark/blob/master/WATERMARK.md"
  exit 1
fi
year=$(date +%Y)
name="Peter Forret"

watermark="$year $name"
echo "--------- START WATERMARK"
echo "Watermark: '$watermark'"
printf "["
  # shellcheck disable=SC2034
splashmark.sh -w 1000 -3 "$watermark" folder "$PWD" \
| while read -r exported ; do
	  printf '.'
	done
echo "]"
echo "--------- FINISH WATERMARK ($SECONDS secs)"
