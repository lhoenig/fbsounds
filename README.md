fbsounds
========

A perl script to download **YouTube, Soundcloud** (as of now) videos from a Facebook page or group and extract the audio! 
  
This is useful for building a massive trackbase, as many music-focused Facebook pages / groups have thousands of links eligible for this batch method!  
The biggest restriction is that this will ONLY work with **PUBLIC pages and groups!**  
Otherwise, I would need to obtain an user app token. I will investigate about this.

## Dependencies  
- perl  
- [ffmpeg](https://github.com/FFmpeg/FFmpeg)  
- [youtube-dl](https://github.com/rg3/youtube-dl) **(Python)**  
  
**fbsounds now comes with the deps/ folder to make installation of dependecies as easy as possible!**

If you have cpan, run `sudo ./deps/deps.sh` from the repository. This will install all required dependencies.   Otherwise, you will have to download and install them manually from [CPAN](https://www.cpan.org).

## Usage  
   
`./fbsounds [ -o <output-dir>  -f <audio-format>  -q <audio-quality> -n <max-downloads> -np -ytdl "args" ] <facebook-id>`  
  
Where `-np` stands for "skip YouTube playlists".  
With `-ytdl "args"` you can add custom arguments to youtube-dl. Wrap them in parentheses.  
See `youtube-dl -h` for available formats, qualities and other options.  
Default format:  **best**  
Default quality: **320K**  

To halt the script while downloading, hit **CTRL-Z** for a SIGKILL.

**IMPORTANT:** For audio conversion to work, you must have the corresponding audio codec library installed, for example lame for mp3 and libvorbis for ogg.  
  
## Contribution  
  
To get your local copy with all the **submodules**, run:  
`git clone --recursive https://github.com/rub1k/fbsounds.git`  
