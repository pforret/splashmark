![GitHub release (latest by date)](https://img.shields.io/github/v/release/pforret/unsplashdl)
![GitHub top language](https://img.shields.io/github/languages/top/pforret/unsplashdl)
![Shellcheck CI](https://github.com/pforret/unsplashdl/workflows/Shellcheck%20CI/badge.svg) 
![Bash CI](https://github.com/pforret/unsplashdl/workflows/Bash%20CI/badge.svg)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/pforret/unsplashdl)
![GitHub issues](https://img.shields.io/github/issues-raw/pforret/unsplashdl)

# unsplashdl

Download unsplash pics and resize/add attribution/... 

    Program: unsplashdl.sh 1.1.0 created on 2020-09-28 by peter@forret.com
    Updated: Oct  2 13:35:29 2020
    Usage: unsplashdl.sh [-h] [-q] [-v] [-l <log_dir>] [-t <tmp_dir>] [-w <width>] [-c <height>] [-p <fonttype>] [-q <fontsize>] [-r <fontcolor>] [-x <effect>] [-1 <northwest>] [-2 <northeast>] [-3 <southwest>] [-4 <southeast>] <action> <output> <input>
    Flags, options and parameters:
        -h|--help      : [flag] show usage [default: off]
        -q|--quiet     : [flag] no output [default: off]
        -v|--verbose   : [flag] output more [default: off]
        -l|--log_dir <val>: [optn] folder for log files   [default: log]
        -t|--tmp_dir <val>: [optn] folder for temp files  [default: .tmp]
        -w|--width <val>: [optn] image width for resizing  [default: 800]
        -c|--height <val>: [optn] image height for cropping  [default: 0]
        -p|--fonttype <val>: [optn] font type family to use  [default: Courier-Bold]
        -q|--fontsize <val>: [optn] font size to use  [default: 12]
        -r|--fontcolor <val>: [optn] font color to use  [default: FFFFFF]
        -x|--effect <val>: [optn] use affect on image: monochrome/blur/pixel
        -1|--northwest <val>: [optn] text to put in left top
        -2|--northeast <val>: [optn] text to put in right top  [default: {url}]
        -3|--southwest <val>: [optn] text to put in left bottom
        -4|--southeast <val>: [optn] text to put in right bottom  [default: {copyright2}]
        <action>  : [parameter] action to perform: download/search
        <output>  : [parameter] output file
        <input>   : [parameter] URL or search term  
        
Example (verbose) output:

        >> unsplashdl.sh -v search examples/night.jpg night
        # init_options: options/flags initialised 
        # Expect :        3 single parameter(s): action output input 
        # Found  : action=search 
        # Found  : output=examples/night.jpg 
        # Found  : input=night 
        # Program: unsplashdl.sh 1.1.0 
        # Updated: Oct  2 13:35:29 2020 
        # Verify : awk basename convert cut date dirname exiftool find grep head mkdir mogrify sed stat tput uname wc  
        # Cleanup folder: [.tmp] - delete files older than 1 day(s) 
        # tmp_file: .tmp/2020-10-02.f0uhEz 
        # Cleanup folder: [log] - delete files older than 7 day(s) 
        # log_file: log/unsplashdl.2020-10-02.log 
        # Cache [.tmp/unsplash.a7d3a8da.json] 
        # URL = [https://api.unsplash.com/search/photos/?query=night&client_id=<id>] 
        # Found photo ID = q3rUTmpZB-Q 
        # Cache [.tmp/unsplash.d7104f0b.json] 
        # URL = [https://api.unsplash.com/photos/q3rUTmpZB-Q?client_id=<id>] 
        # Download = [https://images.unsplash.com/photo-1536746803623-cef87080bfc8?(...))] 
        # Original file = [.tmp/q3rUTmpZB-Q.jpg] 
        # Cache [.tmp/unsplash.d7104f0b.json] 
        # URL = [https://api.unsplash.com/photos/q3rUTmpZB-Q?client_id=<id>] 
        # Cache [.tmp/unsplash.d7104f0b.json] 
        # URL = [https://api.unsplash.com/photos/q3rUTmpZB-Q?client_id=<id>] 
        # Photographer = [Gabriele Motter] 
        # Resize image to 800 wide --> examples/night.jpg 
        # EXIF: set [Artist] to [Gabriele Motter] for [examples/night.jpg] 
        # EXIF: set [OwnerName] to [Gabriele Motter] for [examples/night.jpg] 
        # EXIF: set [Credit] to [unsplash.com] for [examples/night.jpg] 
        # EXIF: set [ImageDescription] to [Photo: Gabriele Motter on Unsplash.com] for [examples/night.jpg] 
        # MARK: [unsplash.com/photos/q3rUTmpZB-Q] in NorthEast corner ... 
        # MARK: [© Gabriele Motter » Unsplash.com] in SouthEast corner ...         examples/night.jpg
        # unsplashdl.sh finished after 3 seconds 

## Examples

    unsplashdl.sh search examples/night.jpg night
![unsplashdl.sh search examples/night.jpg night](examples/night.jpg)

    unsplashdl.sh -w 720 -c 400 search examples/sunny.jpg sunny
![unsplashdl.sh -w 720 -c 400 search examples/sunny.jpg sunny](examples/sunny.jpg)

    unsplashdl.sh -w 720 -c 400 -q 25 -p "Times-Roman" search examples/cocktail.jpg cocktail
![unsplashdl.sh -w 720 -c 400 -q 25 -p "Times-Roman" search examples/cocktail.jpg cocktail](examples/cocktail.jpg)

    unsplashdl.sh -w 720 -c 480 -x light -r 660066 search examples/horse.jpg horse
![unsplashdl.sh -w 720 -c 480 -x light -r 660066 search examples/horse.jpg horse](examples/horse.jpg)
    
    unsplashdl.sh -w 600 -c 600 -p "AvantGarde-Demi" -q 16 -x median,paint,grain  search examples/steak.gif steak
![unsplashdl.sh -w 600 -c 600 -p "AvantGarde-Demi" -q 16 -x median,paint,grain  search examples/steak.gif steak](examples/steak.gif)

    unsplashdl.sh --width 400 --effect grain,bw,light --fontcolor 333333 search examples/puppy.png puppy
![unsplashdl.sh --width 400 --effect grain,bw,light --fontcolor 333333 search examples/puppy.png puppy](examples/puppy.png)

    unsplashdl.sh \
    -p fonts/FiraCode-Regular.ttf \
    -x median,light \
    -1 "font: Fira Code, via Google Fonts" \
    -2 "Photo: {url}" \
    -3 "www.example.com" \
    -4 {copyright} \
    search examples/code.jpg code
![unsplashdl.sh -p fonts/FiraCode-Regular.ttf -x median,light -1 "font: Fira Code, via Google Fonts" -2 "Photo: {url}" -3 "www.example.com" -4 {copyright} search examples/code.jpg code](examples/code.jpg)
---

&copy; 2020 [Peter Forret](https://github.com/pforret)