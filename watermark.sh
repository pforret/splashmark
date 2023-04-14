#!/usr/bin/env bash

folder=$(dirname "$0")
cd "$folder" || exit
[[ ! $(command -v splashmark) ]] && echo "Requires pforret/splashmark" && exit 1
year=$(date +%Y)
name="Peter Forret"

watermark="$year $name"
echo "--------- START WATERMARK"
echo "Watermark: '$watermark'"
printf "["
splashmark.sh -w 1000 -3 "$watermark" folder "$PWD" \
| while read -r exported ; do
	  printf '.'
	done
echo "]"
echo "--------- FINISH WATERMARK ($SECONDS secs)"
