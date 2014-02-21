fbsounds
========

A perl script to download (**youtube, soundcloud** as of now) videos from a Facebook page or group and extract the audio! In other words, you input a FB page / group (the ID) and end up with a bunch of audio files, which is useful for people who want to build a big trackbase, as most music-focused groups on FB have thousands of eligible links for this.
The biggest restriction is that this will ONLY work with **PUBLIC pages and groups**!  
Otherwise, I would need to obtain an user app token. I will investigate how to do this.

## Dependencies  
- perl  
- ffmpeg  
- youtube-dl

If you have cpan, run `sudo ./deps.sh` from the reposity. This will install all required pods. Otherwise, you will have to download and install them manually from [CPAN](https://www.cpan.org).

## Usage  

`./fbsounds [ -o <output-dir>  -f <audio-format>  -q <audio-quality> -n <max-downloads> --np --ytdl "ARGS" ] <facebook-id>`  
  
Where `--np` stands for skip playlists.  
With `--ytdl` "ARGS" you can pass custom arguments to youtube-dl. I suggest wrapping everything in parantheses.  
See youtube-dl -h for available formats and qualities.  
Default format:  **best**  
Default quality: **320K**  

When the script is in download phase, you have to stop it using the KILL signal (usually bound to **ctrl-z**) because otherwise just the next youtube-dl process would be started.  

**IMPORTANT:** For audio conversion to work, you are obliged to have the corresponding audio codec library installed, for example lame for mp3 and libvorbis for ogg.  
