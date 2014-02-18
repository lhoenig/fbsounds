#!/usr/bin/env perl

use strict;
use warnings;

use constant DEBUG => 0;

use JSON;
use LWP::UserAgent;
use URI::Encode;
use Getopt::Long;
use Data::Dumper;
use Term::ANSIColor;

local $| = 1;   # autoflush stdout

# to avoid overhead
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

# output directory, default cwd
my $outputDir = ".";

# default audio format (youtube-dl)
my $audioFormat = "best";

# default audio quality (youtube-dl)
my $audioQuality = "320K";

# skip playlists flag
my $skipPlaylists = 0;

# read command line options
GetOptions ("o=s"        => \$outputDir,
            "f=s"        => \$audioFormat,
            "q=s"        => \$audioQuality,
            "np"         => \$skipPlaylists)
or die("Error in command line arguments\n");

# now the target is the last argument
$target = $ARGV[$#ARGV];

# at least we need a target
if (!(defined $target)) {
    usage_string(); 
}

# entries per page
my $limit = 100;

# where the links go
my @link_array;


sub usage_string {
    print "Usage: " . $0 . " [ -o <output-dir>  -f <audio-format>  -q <audio-quality>  -np ] <facebook-id>\
    \rSee youtube-dl -h for available formats and qualities.\
    \rDefault format:\t\t$audioFormat\nDefault quality:\t$audioQuality\n";
    exit(1);
}


sub dbg {
    print colored("DEBUG: ", "red") . colored($_[0], "white") . "\n" if DEBUG;
}


# using http://awpny.com/how-to-facebook-access-token/
# and uberspace.com!
sub get_access_token {
    
    my $query = "https://fbsounds.triangulum.uberspace.de/token";
    my $req = HTTP::Request->new(GET => $query);
    my $res = $ua->request($req);
    
        dbg("token query: " . $query);

    if ($res->is_success) {
        return $res->content;
    } else {
        die("Failed to get access token");
    }
}





########### MAIN ###############################################################################

# generate token because it changes over time
my $access_token = get_access_token();

    dbg("token: " . $access_token);


# first page
my $start_url = "https://graph.facebook.com/$target/feed?fields=link&access_token=$access_token&limit=$limit";

    dbg("start_url: " . $start_url);


# get the fb entity name
my $fbName = fb_name($target);

    dbg("fb_name: " . $fbName);
    
print "\nGetting links for " . colored("\"$fbName\"", "yellow") .  "...\n\n";
print "Links: " . colored("0\r", "bold green");


# get the video links, starting from first page
my $next_page = $start_url;
while ($next_page = get_links($next_page)) {}



# filter duplicate links
@link_array = keys %{{ map{$_=>1}@link_array}};


# https://github.com/rub1k/fbsounds/issues/7


# final output of number of extracted links
my $n_links = $#link_array + 1;
print "Links: " . colored("$n_links\r", "bold green") . "\n";


# we got some links
if (@link_array) {

    # download and convert files    
    download_vids(@link_array);

    print colored("\nDone.\n\n", "yellow");
} else {
    print colored("\nNo links found.\n\n", "yellow");
}

#################################################################################################


# debug: list of extracted links, maybe incremental downloads in the future?
sub file_append {
    
    open(OFILE, '>>links.txt');
    print OFILE $_[0] . "\n";
    close(OFILE);
}


# get name from fb-id
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
        print("\nFailed to get name from facebook id\n");
        exit(1);
    }
}


# check if link is downloadable
sub qualifies {
    
    my $candidate = $_[0];
    my $res = 0;
    
        #dbg($candidate);

    # https://github.com/rub1k/fbsounds/issues/10
    # https://github.com/rub1k/fbsounds/issues/9

    my @matches = ("youtu.be/",
                   "youtube.com/",
                   "soundcloud.com/");
    
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
                
                #file_append($link);
                
                # add to download queue
                push(@link_array, $link);
                
                # show progress
                print "Links: " . colored("$#link_array\r", "bold green");
              }
        }
        
        my $next = $uri->encode($decoded->{paging}->{next});
        
        if (defined $next) {
            return $next;
        } else {
            return 0;   # there is no next page
        }

    # request failed
    } else {
        print $res->status_line . "\n";
		exit(1);
    }
}

# colored total progress line
# arguments: current vid, total number of vids
sub progress_line {
    
    my $max = $_[1] + 1;
    my $msg = colored("\n[==========]", "yellow") . 
              colored(" $_[0] / $max ", "bright_blue") . 
              colored("[==========]" , "yellow") . "\n";
        
    return $msg;
}


# download and convert all videos using youtube-dl
sub download_vids {
    
    my $n = 1;
    foreach my $vid_link (@_) {
        
        print progress_line($n, $#_);
        
        # constructed youtube-dl call
        # https://github.com/rub1k/fbsounds/issues/1
        # https://github.com/rub1k/fbsounds/issues/2
        # https://github.com/rub1k/fbsounds/issues/6
        my $ret;
        if ($skipPlaylists) {
            $ret = system("youtube-dl -i --no-playlist -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"");   
        } else {
            $ret = system("youtube-dl -i -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"");   
        }
        
        # https://github.com/rub1k/fbsounds/issues/3
        #if ($ret == 256) {  # kill every subprocess
        #    kill 9 => $$; }
        
        # https://github.com/rub1k/fbsounds/issues/8 (tagging files)

        $n++;
    }
    
}
