fbsounds
========

A perl script to download **YouTube, Soundcloud** (as of now) videos from a Facebook page or group and extract the audio! 

This is useful for quickly building a massive trackbase, as many music-focused Facebook pages / groups have thousands of links eligible for this batch downloading/converting method!  
The biggest restriction is that this will **ATM** only work with **PUBLIC pages and groups!**  
Otherwise, I would need to obtain an user app token, im not entirely sure. I will need to investigate this.

## Dependencies  
  
**NEW: deps/ folder to make installation of dependecies as easy as possible! Files for the major platforms.**
  
- perl  
- [ffmpeg](https://github.com/FFmpeg/FFmpeg)  
- [youtube-dl](https://github.com/rg3/youtube-dl) **(Python)**  
  
If you have cpan, run `sudo deps/deps.sh` from the repository. This will install all required dependencies.   Otherwise, you will have to download and install them manually from [CPAN](https://www.cpan.org).

## Usage  
   
`./fbsounds [ -o <output-dir>  -f <audio-format>  -q <audio-quality> -n <max-downloads> -n max_videos -r -np -ytdl "args" ] <facebook-id>`  
  
Where `-np` stands for "skip YouTube playlists".  
When `-r` is given a retry on error will be performed.  
With `-ytdl "args"` you can add custom arguments to youtube-dl. Wrap them in parentheses.
Limit the number of processed videos with the `-n` flag.  
See `youtube-dl -h` for available formats, qualities and other options.  
Default format:  **best**  
Default quality: **320K**  

To halt the script while downloading, hit **CTRL-Z** for a SIGKILL.  
Wait.. could I possibly add a signal handler to the youtube-dl system call? **TODO**

**IMPORTANT:** For audio conversion to work, you must have the corresponding audio codec library installed, for example lame for mp3 and libvorbis for ogg.  
  
## Contribution  
  
To get your local copy with **all the submodules**:  
`git clone --recursive https://github.com/rub1k/fbsounds.git`  
