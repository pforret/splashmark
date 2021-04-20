![GitHub release (latest by date)](https://img.shields.io/github/v/release/pforret/splashmark)
![GitHub top language](https://img.shields.io/github/languages/top/pforret/splashmark)
![Shellcheck CI](https://github.com/pforret/splashmark/workflows/Shellcheck%20CI/badge.svg) 
![Bash CI](https://github.com/pforret/splashmark/workflows/Bash%20CI/badge.svg)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/pforret/splashmark)
![GitHub issues](https://img.shields.io/github/issues-raw/pforret/splashmark)
[![basher install](https://img.shields.io/badge/basher-install-white?logo=gnu-bash&style=flat)](https://basher.gitparade.com/package/)

# splashmark

![splashmark logo](assets/splash.jpg)

Remix images by
* resize/crop
* add visual FX (blur/monochrome/darken/median/grain...)
* add attribution (by saving it as EXIF/IPTC meta data)
* add watermarks (Unsplash URL or other)

Works with
* local image file
* image URL
* Unsplash image

## Usage

```bash
Program: splashmark 3.0.0 by peter@forret.com
Updated: Apr 20 22:27:45 2021
Description: package_description
Usage: splashmark [-h] [-q] [-v] [-l <log_dir>] [-t <tmp_dir>] [-w <width>] [-c <crop>] [-1 <northwest>] [-2 <northeast>] [-3 <southwest>] [-4 <southeast>] [-d <randomize>] [-e <effect>] [-g <gravity>] [-i <title>] [-z <titlesize>] [-k <subtitle>] [-j <subtitlesize>] [-m <margin>] [-o <fontsize>] [-p <fonttype>] [-r <fontcolor>] [-x <photographer>] [-u <url>] [-P <PIXABAY_ACCESSKEY>] [-U <UNSPLASH_ACCESSKEY>] <action> <input?> <output?>
Flags, options and parameters:
    -h|--help        : [flag] show usage [default: off]
    -q|--quiet       : [flag] no output [default: off]
    -v|--verbose     : [flag] output more [default: off]
    -l|--log_dir <?> : [option] folder for log files   [default: /Users/pforret/log/splashmark]
    -t|--tmp_dir <?> : [option] folder for temp files  [default: /tmp/splashmark]
    -w|--width <?>   : [option] image width for resizing  [default: 1200]
    -c|--crop <?>    : [option] image height for cropping  [default: 0]
    -1|--northwest <?>: [option] text to put in left top
    -2|--northeast <?>: [option] text to put in right top  [default: {url}]
    -3|--southwest <?>: [option] text to put in left bottom  [default: Created with pforret/splashmark]
    -4|--southeast <?>: [option] text to put in right bottom  [default: {copyright2}]
    -d|--randomize <?>: [option] take a random picture in the first N results  [default: 1]
    -e|--effect <?>  : [option] use effect chain on image: bw/blur/dark/grain/light/median/paint/pixel
    -g|--gravity <?> : [option] title alignment left/center/right  [default: center]
    -i|--title <?>   : [option] big text to put in center
    -z|--titlesize <?>: [option] font size for title  [default: 80]
    -k|--subtitle <?>: [option] big text to put in center
    -j|--subtitlesize <?>: [option] font size for subtitle  [default: 50]
    -m|--margin <?>  : [option] margin for watermarks  [default: 30]
    -o|--fontsize <?>: [option] font size for watermarks  [default: 15]
    -p|--fonttype <?>: [option] font type family to use  [default: FiraSansExtraCondensed-Bold.ttf]
    -r|--fontcolor <?>: [option] font color to use  [default: FFFFFF]
    -x|--photographer <?>: [option] photographer name (empty: use name from API)
    -u|--url <?>     : [option] photo URL override (empty: use URL from API)
    -P|--PIXABAY_ACCESSKEY <?>: [option] Pixabay access key
    -U|--UNSPLASH_ACCESSKEY <?>: [option] Unsplash access key
    <action>         : [parameter] action to perform: unsplash/file/url
    <input>          : [parameter] URL or search term (optional)
    <output>         : [parameter] output file (optional)
                                  @github.com:pforret/splashmark.git                                             
### TIPS & EXAMPLES
* use splashmark unsplash to download or search a Unsplash photo (requires free Unsplash API key)
  splashmark unsplash "https://unsplash.com/photos/lGo_E2XonWY" rose.jpg
  splashmark unsplash rose rose.jpg
  splashmark unsplash rose (will generate unsplash.rose.jpg)
* use splashmark pixabay to download or search a Pixabay photo (requires free Pixabay API key)
  splashmark pixabay "https://pixabay.com/photos/rose-flower-love-romance-beautiful-729509/" rose.jpg
  splashmark pixabay rose rose.jpg
  splashmark pixabay rose (will generate pixabay.rose.jpg)
* use splashmark file to add texts and effects to a existing image
  splashmark file waterfall.jpg sources/original.jpg
  splashmark --title "Strawberry" -w 1280 -c 640 -e dark,median,grain file sources/original.jpg waterfall.jpg
* use splashmark url to add texts and effects to a image that will be downloaded from a URL
  splashmark file waterfall.jpg "https://i.imgur.com/rbXZcVH.jpg"
  splashmark -w 1280 -c 640 -4 "Photographer: John Doe" -e dark,median,grain url "https://i.imgur.com/rbXZcVH.jpg" waterfall.jpg
* use splashmark check to check if this script is ready to execute and what values the options/flags are
  splashmark check
* use splashmark env to generate an example .env file
  splashmark env > .env
* to create a social image for Github
  splashmark -w 1280 -c 640 -z 100 -i "<user>/<repo>" -k "line 1\nline 2" 
    -r EEEEEE -e median,dark,grain unsplash <keyword>
* to create a social image for Instagram
  splashmark -w 1080 -c 1080 -z 150 -i "Carpe diem" -e dark 
    pixabay clouds clouds.jpg
* to create a social image for Facebook
  splashmark -w 1200 -c 630 -i "20 worldwide destinations\nwith the best beaches" 
    -e dark unsplash copacabana                
```

## installation

1. install requirements

```bash
# On Linux
sudo apt install exiftool imagemagick
# on MacOS
brew install exiftool imagemagick
```
2. via [basher](https://github.com/basherpm/basher)

```bash
basher install pforret/splashmark
```

2. or otherwise clone the repo
```bash
git clone https://github.com/pforret/splashmark.git
sudo ln -s splashmark/splashmark /usr/bin/
```

        
3. configure Unsplash API keys on [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications)

4. install API keys

```bash
cp splashmark/.env.example splashmark/.env
vi splashmark/.env
# copy/paste `UNSPLASH_ACCESSKEY` value
```
## Example (verbose) output:

        $ splashmark -w 800 -p UbuntuMono-Bold.ttf -e median,dark,grain -1 "font: UbuntuMono Bold, via Google Fonts" -2 "Photo: {url}" -3 "www.example.com" -4 {copyright} -i "Just an example" -v search examples/example.jpg beach
        
        # Expect : 3 single parameter(s): action output input 
        # Found  : action=search 
        # Found  : output=examples/example.jpg 
        # Found  : input=beach 
        # Program: splashmark 2.3.0 
        # Updated: 2020-10-10 13:45 
        # Running: on Linux (#488-Microsoft Mon Sep 01 13:43:00 PST 2020) 
        # Verify : awk basename convert cut date dirname exiftool find grep head mkdir mogrify sed stat tput uname wc  
        # Cleanup folder: [.tmp] - delete files older than 1 day(s) 
        # tmp_file: .tmp/2020-10-19.xzAVHb 
        # Cleanup folder: [log] - delete files older than 7 day(s) 
        # log_file: log/splashmark.2020-10-19.log 
        # API = [.tmp/unsplash.f499e0ec.json] 
        # Found photo ID = fbbxMwwKqZk 
        # API = [.tmp/unsplash.4704b4c4.json] 
        # IMG = [.tmp/fbbxMwwKqZk.jpg] 
        # API = [.tmp/unsplash.4704b4c4.json] 
        # API = [.tmp/unsplash.4704b4c4.json] 
        # FONT [./fonts/UbuntuMono-Bold.ttf] exists as a splashmark font 
        # SIZE: to 800 wide --> examples/example.jpg 
        # EXIF: set [Writer-Editor] to [splashmark] for [examples/example.jpg] 
        # EXIF: set [Artist] to [Boxed Water Is Better] for [examples/example.jpg] 
        # EXIF: set [Creator] to [Boxed Water Is Better] for [examples/example.jpg] 
        # EXIF: set [OwnerID] to [Boxed Water Is Better] for [examples/example.jpg] 
        # EXIF: set [OwnerName] to [Boxed Water Is Better] for [examples/example.jpg] 
        # EXIF: set [Credit] to [Photo: Boxed Water Is Better on Unsplash.com] for [examples/example.jpg] 
        # EXIF: set [ImageDescription] to [Photo: Boxed Water Is Better on Unsplash.com] for [examples/example.jpg] 
        # EFX : median 
        # EFX : dark 
        # EFX : grain 
        # MARK: [font: UbuntuMono Bold, via Google Fonts] in NorthWest corner ... 
        # MARK: [Photo: unsplash.com/photos/fbbxMwwKqZk] in NorthEast corner ... 
        # MARK: [www.example.com] in SouthWest corner ... 
        # MARK: [Photo by Boxed Water Is Better on Unsplash.com] in SouthEast corner ... 
        # MARK: title [Just an example] in Center ... 
        examples/example.jpg
        # splashmark finished after 5 seconds

![example.jpg](examples/example.jpg)

## Examples
check [EXAMPLES.md](https://github.com/pforret/splashmark/blob/master/EXAMPLES.md)


## Common image sizes
* [facebook-profile-picture-size-and-more](https://www.godaddy.com/garage/facebook-profile-picture-size-and-more/)
---

&copy; 2020 [Peter Forret](https://github.com/pforret)