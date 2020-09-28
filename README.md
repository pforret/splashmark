# unsplashdl

Download unsplash pics and resize/add attribution/... 

    Program: unsplashdl.sh 1.0.3 created on 2020-09-28 by peter@forret.com
    Updated: Sep 29 00:10:09 2020
    Usage: unsplashdl.sh [-h] [-q] [-v] [-f] [-l <log_dir>] [-t <tmp_dir>] [-w <width>] [-c <height>] <action> <output> <input>
    Flags, options and parameters:
        -h|--help      : [flag] show usage [default: off]
        -q|--quiet     : [flag] no output [default: off]
        -v|--verbose   : [flag] output more [default: off]
        -f|--force     : [flag] do not ask for confirmation (always yes) [default: off]
        -l|--log_dir <val>: [optn] folder for log files   [default: log]
        -t|--tmp_dir <val>: [optn] folder for temp files  [default: .tmp]
        -w|--width <val>: [optn] image width for resizing  [default: 1080]
        -c|--height <val>: [optn] image height for cropping  [default: 0]
        <action>  : [parameter] action to perform: download/search
        <output>  : [parameter] output file
        <input>   : [parameter] URL or search term

Example (verbose) output:

        > unsplashdl.sh -v -w 800 -c 800 search bird.jpg bird
        (...)
        # Cache [.tmp/unsplash.0ab744da.json] 
        # URL = [https://api.unsplash.com/search/photos/?query=bird&client_id=(...)] 
        # Found photo ID = e-S-Pe2EmrE 
        # Cache [.tmp/unsplash.38d07335.json] 
        # URL = [https://api.unsplash.com/photos/e-S-Pe2EmrE?client_id=(...))] 
        # Download = [https://images.unsplash.com/photo-1433321768402-897b0324c?(...)] 
        # Original file = [.tmp/e-S-Pe2EmrE.jpg] 
        # Cache [.tmp/unsplash.38d07335.json] 
        # URL = [https://api.unsplash.com/photos/e-S-Pe2EmrE?client_id=(...)] 
        # Photographer = [Rowan Heuvel] 
        # Resize & crop image to 800 x 800 --> bird.jpg 
        # EXIF: set [Artist] to [Rowan Heuvel] for [bird.jpg] 
        # EXIF: set [OwnerName] to [Rowan Heuvel] for [bird.jpg] 
        # EXIF: set [Credit] to [unsplash.com] for [bird.jpg] 
        # EXIF: set [ImageDescription] to [Photo: Rowan Heuvel on Unsplash.com] for [bird.jpg] 
        # unsplashdl.sh finished after 2 seconds 

&copy; 2020 [Peter Forret](https://github.com/pforret)