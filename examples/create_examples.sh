#!/bin/bash
examples_folder=$(dirname "$0")
script_folder=$(dirname "$examples_folder")
script="$script_folder/splashmark"

create(){
  echo "        splashmark $@"
  output=$("$script" "$@")
  echo "output: $output" >&2
  echo "![splashmark $*]($output)"
  echo "---"
  echo " "
}

echo "# SplashMark examples"
echo " "

create download "$examples_folder/basic_scale.jpg" https://unsplash.com/photos/FzthdgL6vBI

create -w 700 -c 600 search "$examples_folder/basic_crop.jpg" night

create -w 800 -c 800 --randomize 5 -e dark,grain -i "take random photo\nfrom Unsplash\nsearch results" search "$examples_folder/random.jpg" tree

create -w 700 -c 500 -e light,grain -i "filter: light,grain" search "$examples_folder/fx_horse.jpg" horse

create -w 1000 -c 600 -p "AvantGarde-Demi" -o 16 -i "Custom fonts" -e median,paint,grain  search "$examples_folder/text_fonts.gif" steak

create --width 800 --crop 800 --effect bw,light,grain --fontcolor 000 --title "multi\nline\ntext" search "$examples_folder/text_lines.png" puppy

create -w 1000 -c 500 -p FiraCode-Regular.ttf -o 12 -e paint,dark,grain -i "Use the 4 corners" \
  -1 "font: Fira Code, via Google Fonts" -2 "Photo: {url}" -3 "www.example.com" -4 "{copyright}" \
  search "$examples_folder/text_corners.jpg" code

create -w 700 -c 600 -e dark,blur,grain -z 100 -g West -p FiraSansExtraCondensed-Bold.ttf -i "Left\naligned" search "$examples_folder/text_left.jpg" paris

create -m 30 -w 800 -c 800 -e dark,grain \
  -r FFFD -z 100 -i "Big titles" -j 40 -k "as well as small smaller subtitles" -p "SansitaSwashed-Bold.ttf" \
  search "$examples_folder/text_subtitles.jpg" hope

create -w 1280 -c 640 -i "sized for Github\n'social preview':\n1280x640" -e dark,grain -3 "created with pforret/splashmark" -p fonts/FiraCode-Regular.ttf \
  search "$examples_folder/size_github.jpg" splash

create -w 1080 -c 1080 -e dark,grain \
  -i "Sized for instagram posts:\n1080x1080" -p "SansitaSwashed-Bold.ttf" \
  search "$examples_folder/size_instagram.jpg" beach

create -w 1500 -c 500 \
  -i "Sized for Twitter cover photo:\n1500x500" \
  search "$examples_folder/size_twitter.jpg" sea

create -w 1200 -c 630 -e dark,grain \
  -i "Sized for Facebook post:\n1200x630" \
  search "$examples_folder/size_facebook.jpg" friends

