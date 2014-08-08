#!/usr/bin/env perl

package fbsounds;

use strict;
use warnings;

use constant DEBUG => 0;
use constant LIMIT => 100;

use Term::ANSIColor;
use LWP::UserAgent;
use Getopt::Long;
use Data::Dumper;
use URI::Encode;
use JSON;

local $| = 1;   # autoflush stdout


# global copies
my $ua  = LWP::UserAgent->new;
my $uri = URI::Encode->new( { encode_reserved => 0 } );
my $json = JSON->new->allow_nonref;


# facebook group or site
my $target;

# example groups

# the29nov films
#my $target = "113397788684941";
# the29nov core
#my $target = "108775282491150";


# output directory
my $outputDir;

# default audio format (youtube-dl)
my $audioFormat = "best";

# default audio quality (youtube-dl)
my $audioQuality = "0";

# skip yt playlists flag
my $skipPlaylists = 0;

# maximum number of videos to download
my $vMax = 0;

# where the links go
my @link_array;

# videos who exited abnormally
my @failed_vids;

# additional youtube-dl args provided by -ytdl
my $dl_args = "";

my $retry = 0;

# process command line options
GetOptions ("o=s"        => \$outputDir,
            "f=s"        => \$audioFormat,      # yt-dl audio format
            "q=s"        => \$audioQuality,     # yt-dl audio quality
            "sp"         => \$skipPlaylists,    # youtube-dl follows them by default
            "n=i"        => \$vMax,             # can be used to the head of a feed
            "ytdl=s"     => \$dl_args,          # arguments passed to yt-dl
            "r"          => \$retry)            # retry once if errors occured while downloading
or die("Error in command line arguments\n");

# now target is the only argument
$target = $ARGV[0];

unless (defined $target) {
    usage(); 
}



# generate token everytime as it changes with time
my $access_token = get_access_token();

dbg("access_token: " . $access_token);



# if output is omitted, set to fb entity name
unless (defined $outputDir) {

    # replace non-ascii chars with _
    my $name = fb_name($target);
    $name =~ s/[^[:ascii:]]/_/g;
    
    $outputDir = $name;
}



# print usage, exit 1
sub usage {

    print "Usage: " . $0 . " [ -o <output-dir>  -f <audio-format>  -q <audio-quality> -n <max downloads> -r -sp -ytdl \"args\" ] <facebook-id>\
    \n\rSee youtube-dl -h for available formats and qualities.\
    \rDefault format:\t\t$audioFormat\nDefault quality:\t$audioQuality\n\n";
    exit(1);
}

# colored debug messages: red and white
sub dbg {
    print colored("DEBUG: ", "red") . colored($_[0], "white") . "\n" if DEBUG;
}



# using http://awpny.com/how-to-facebook-access-token/
# and uberspace!
sub get_access_token {
    
    my $query = "https://fbsounds.triangulum.uberspace.de/token";
    my $req = HTTP::Request->new(GET => $query);
    my $res = $ua->request($req);
    
    dbg("token query: " . $query);

    if ($res->is_success) {
        return $res->content;
    } else {
        die("Failed to get access token: " . $res->status_line);
    }
}



########### MAIN #######################################################################################


# first page to curl
my $start_url = "https://graph.facebook.com/$target/feed?fields=link&access_token=$access_token&limit=". LIMIT;

dbg("start_url: " . $start_url);


# get fb entity name
my $fbName = fb_name($target);

dbg("fb_name: " . $fbName);

print "\nGetting links for " . colored("\"$fbName\"", "yellow") .  " ...\n\n";
print "Links: " . colored("0\r", "bold green");


# get the video links, starting from first page
my $next_page = $start_url;
while ($next_page = get_links($next_page)) {}


# final output before downloading
my $n_links = $#link_array + 1;
print "Links: " . colored("$n_links\r", "bold green") . "\n";


if (@link_array) {

    # filter duplicate links
    @link_array = keys %{{ map{$_=>1} @link_array }};

    
    dbg("B drop_finished: " . ($#link_array +1));

    # remove done links downloaded before
    drop_finished();

    dbg("A drop_finished: " . ($#link_array + 1));


    # download and convert to audio files
    download_vids(@link_array);
    
    if (@failed_vids && $retry) {
        download_vids(@failed_vids);   # try again once
    }

    print "\nDone.\n\n";

} else {    
    print colored("\nNo links found.\n\n", "yellow");
}


#########################################################################################################



# avoid redownloading videos
sub drop_finished {

    my $fname = "$ENV{HOME}/.fbsounds/.$target.links";   
    my $content = "";

    if (!(-e "$ENV{HOME}/.fbsounds/")) {
        mkdir("$ENV{HOME}/.fbsounds") or die "could not create directory $ENV{HOME}/.fbsounds: $? $@";       
    }

    my $fh;
    if ( -e $fname ) {
        open($fh, '<', $fname) or die "cannot open file $fname";
    } else {
        system("touch $fname");
        open($fh, '<', $fname) or die "cannot open file $fname";
    }
    while (<$fh>) { $content .= $_; }

    #dbg("Content in drop_finished:\n" . $content);

    foreach my $vid (@link_array) {

        #dbg("Checking for $vid ...");
        
        if ($content =~ /\Q$vid\E/) {

            my $index = grep { $link_array[$_] =~ /$vid/ } 0..$#link_array;            
            splice(@link_array, $index, 1);
            
            dbg("Skipping link: " . $vid);

        } else {
            #dbg("Link " . $vid . " not found in history file $fname");
        }
    }
    close($fh);
}



# add link to .links file for facebook id if not already present
sub history_add {
    
    my $fname = "$ENV{HOME}/.fbsounds/.$target.links";    
    my $content = "";

    # when fbsounds runs for the first time, it creates a .fbsounds folder in ~/
    if (!(-e "$ENV{HOME}/.fbsounds/")) {
        mkdir("$ENV{HOME}/.fbsounds") or die "could not create directory $ENV{HOME}/.fbsounds: $? $@";       
    }

    # read file into $content
        open(my $fh, '+>>', $fname) or die "cannot open file $fname";
        
        # seek to beginning, because atm $fh points to EOF
        seek($fh, 0, 0);
        while (<$fh>) { $content .= $_; }

        dbg("Content in history_add:\n" . $content);

    # append to links file if not found 
        
        if (!($content =~ /\Q$_[0]\E/)) {
            dbg("Link $_[0] not found, appending to $fname");
            
            # seek to EOF (append)   
            seek($fh, 0, 2);
            print $fh $_[0] . "\n";
        }
        
    close($fh); 
}




# get name field from facebook id
sub fb_name {
    
    my $query = "https://graph.facebook.com/$_[0]?fields=name&access_token=$access_token";
    my $req = HTTP::Request->new(GET => $query);
	my $res = $ua->request($req);
    
    dbg("fb_name query: " . $query) if DEBUG;

    if ($res->is_success) {
        
        my $decoded = decode_json($res->content);
        return $decoded->{name};
        
    } else {
        print "\n" . $res->status_line . "\n" . $res->content . "\n";
        print("\nFailed to get name from facebook id $_[0]\n");
        exit(1);
    }
}




# check if link is downloadable
sub qualifies {
    
    my $candidate = $_[0];
    my $res = 0;
    
    # https://github.com/rub1k/fbsounds/issues/10
    # https://github.com/rub1k/fbsounds/issues/9

    my @matches = ("youtu.be/",
                   "youtube.com/",
                   "soundcloud.com/",
                   "myvideo.de/");
    
    foreach my $expr (@matches) {
        if (index($candidate, $expr) != -1) {
            $res = 1;
        }
    }
    return $res;
}





# get links from facebook graph api
sub get_links {
    
    my $req = HTTP::Request->new(GET => $_[0]);
	my $res = $ua->request($req);
    if ($res->is_success) {
        
        #dbg($res->content);

        my $decoded = decode_json($res->content);
        
        foreach my $d (@{ $decoded->{data} }) {

            my $link = $d->{link};
            if (defined $link && qualifies($link)) {
                
                if ($vMax && ($vMax == ($#link_array + 1))) {       # specified maximum reached
                    return 0;
                } else {
                    push(@link_array, $link);                    
                }
                
                print "Links: " . colored("$#link_array\r", "bold green");     # show progress
              }
        }
        
        my $next = $uri->encode($decoded->{paging}->{next});
        
        if (defined $next) {
            return $next;
        } else {
            return 0;   # there is no next page
        }

    } else {  # request failed
        print $res->status_line . "\n";
		exit(1);
    }
}




# colored total progress line
# arguments: current vids, total number of vids
sub progress_line {
    
    my $max = $_[1] + 1;
    my $msg = colored("\n[==========]", "yellow") . 
              colored(" $_[0] / $max ", "bright_green") . 
              colored("[==========]" , "yellow") . "\n";
    
    return $msg;
}




# download and convert all videos using youtube-dl
sub download_vids {
    
    my $n = 1;

    foreach my $vid_link (@_) {
        
        print progress_line($n, $#_);
        
        # constructed youtube-dl call
        my $call;
        if ($skipPlaylists) {
            
            $call = "youtube-dl " . $dl_args . " -i --no-playlist -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"";
        } else {
            
            $call = "youtube-dl " . $dl_args . " -i -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"";
        }
        my $ret = system($call);   
        
        print "\n";
        
        dbg("youtube-dl return code: " . $ret);

        if ($ret == 0) {
            
            # download successful, add to history
            history_add($vid_link);
        
            dbg("Added $vid_link to history");
        
        } else {
            push(@failed_vids, $vid_link);
        }
        
        # https://github.com/rub1k/fbsounds/issues/8 (tagging files)

        $n++;
    }
}
