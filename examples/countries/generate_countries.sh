#!/usr/bin/env bash

countries_url="https://gist.githubusercontent.com/kalinchernev/486393efcca01623b18d/raw/daa24c9fea66afb7d68f8d69f0c4b8eeb9406e83/countries"
countries_file="countries.txt"

[[ ! -f "$countries_file" ]] && curl -s "$countries_url" > "$countries_file"

  cat "$countries_file" \
| while read -r country ; do
    slug=$(echo "$country" | sed 's/[^a-zA-Z]//g')
    search=$(echo "$country" | sed 's/ /+/g')
    title=$(echo "$country" | tr ' ' "\n")
    [[ ! -f ${slug}_ig.jpg ]] && echo "### $country ..."  && ../../splashmark -w 800 -c 800 -z 160 -i "$title" -r "FFFFFFCC" -e dark search ${slug}_ig.jpg "$search" && sleep 60
    #[[ ! -f ${slug}_fb.jpg ]] && splashmark -w 1200 -c 630 -i "$country" search ${slug}_fb.jpg "$search" && sleep 10
  done