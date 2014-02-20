fbsounds
========

A script to download certain ( youtube, soundcloud ) videos from a Facebook page or group and extract the audio! 
The biggest restriction is that this will ONLY work with **PUBLIC pages and groups**!  
Otherwise, i would need to obtain an user app token. I will investigate how to do this.

## Dependencies  
- perl  
- ffmpeg  
- youtube-dl

If you have cpan, run `sudo ./deps.sh` from the reposity. This will install all required pods. Otherwise, you will have to download and install them manually from [CPAN](https://www.cpan.org).

## Usage  

`./fbsounds [ -o <output-dir>  -f <audio-format>  -q <audio-quality> -n <max-downloads> --np ] <facebook-id>`  
  
Where `--np` stands for skip playlists.  
See youtube-dl -h for available formats and qualities.  
Default format:  **best**  
Default quality: **320K**  

**IMPORTANT:** For audio conversion to work, you are obliged to have the corresponding audio codec library installed, for example lame for mp3 and libvorbis for ogg.  
