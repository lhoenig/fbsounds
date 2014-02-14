fbsounds
========

Download all youtube videos from a Facebook page or group and convert them to audio files!  
The current restriction is that this will ONLY work with PUBLIC pages and groups!  
otherwise, i would need to obtain an user app token. will investigate how to do this.

### Dependencies  
- perl  
- ffmpeg  
- youtube-dl

perl will tell you which modules you are missing.

### Usage  

`./fbsounds [-o <output-dir>  -f <audio-format>  -q <audio-quality>] <facebook-id>`  
See youtube-dl -h for available formats and qualities.  
Default format: aac  
       quality: 320K

IMPORTANT: For audio conversion to work, you have to habe the corresponding audio codec library installed for example lame or libvorbis.

### TODO's  
  
- soundcloud downloads :)
