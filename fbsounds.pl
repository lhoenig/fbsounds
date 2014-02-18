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

my $ua  = LWP::UserAgent->new;
my $uri = URI::Encode->new( { encode_reserved => 0 } );
my $json = JSON->new->allow_nonref;


sub usage_string {
    print "Usage: " . $0 . " [-o <output-dir>  -f <audio-format>  -q <audio-quality>] <facebook-id>\
    \rSee youtube-dl -h for available formats and qualities.\
    \rDefault\tformat:\t\taac\n\tquality:\t320K\n";
    exit(1);
}

sub dbg {
    print colored("DEBUG: ", "red") . colored($_[0], "white") . "\n" if DEBUG;
}


# example groups

# the29nov films
#my $group = "113397788684941";
# the29nov core
#my $group = "108775282491150";

# facebook group or site
my $group = $ARGV[$#ARGV];

# output directory, default cwd
my $outputDir = ".";

# audio format (youtube-dl)
my $audioFormat = "aac";

# audio quality (youtube-dl)
my $audioQuality = "320K";

# read command line options
GetOptions ("o=s"        => \$outputDir,
            "f=s"        => \$audioFormat,
            "q=s"        => \$audioQuality)
or die("Error in command line arguments\n");

# we at least need a target
if (!(defined $group)) {
    usage_string(); 
}


#
# generated using http://awpny.com/how-to-facebook-access-token/
# anduberspace!
#
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

# entries per page
my $limit = 100;

# where the links go
my @link_array;



########### MAIN ###############################################################################

# generate token because it changes over time
my $access_token = get_access_token();

    dbg("token: " . $access_token);


# first page
my $start_url = "https://graph.facebook.com/$group/feed?fields=link&access_token=$access_token&limit=$limit";

    dbg("Start: " . $start_url);


# get the fb entity name
my $fbName = fb_name($group);

print "\nGetting links for " . colored("\"$fbName\"", "yellow") .  "...\n\n";
print colored("Links: ", "yellow") . colored("0\r", "bright_blue");


# get the video links
get_links($start_url);


# filter duplicate links
@link_array = keys %{{ map{$_=>1}@link_array}};

my $n_links = $#link_array + 1;
print colored("Links: ", "yellow") . colored("$n_links\r", "bright_blue") . "\n";

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
    
    # TODO in the future we may be able to download soundcloud links too (quality?)
    # TODO filter based on minimum quality
    # TODO incremental downloads

    my @matches = ("youtu.be",
                   "youtube.com");
    
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
                
                # inform of progress
                print colored("Links: ", "yellow") . colored("$#link_array\r", "bright_blue");
              }
        }
        
        my $next = $uri->encode($decoded->{paging}->{next});
        
        if (defined $next) {

            # again with next page, 
            # maybe in the future we will remove the recursion
            get_links($next);
        }

    # request failed
    } else {
        print $res->status_line . "\n";
		exit(1);
    }
}


sub progress_line {
    
    my $max = $_[1] + 1;
    my $msg = colored("\n[==========]", "yellow") . 
              colored(" $_[0] / $max ", "bright_blue") . 
              colored("[==========]" , "yellow") . "\n";
        
    return $msg;
}


# download and convert all videos
sub download_vids {
    
    my $n = 1;
    foreach my $vid_link (@_) {
        
        print progress_line($n, $#_);
        
        # constructed youtube-dl call
        # TODO add --no-playlist switch
        # TODO NO- pass all arguments to youtube-dl
        # Maybe i should rather contribute to the Facebook extractor of youtube-dl after all
        # TODO ignore errors
        my $ret = system("youtube-dl -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"");
        
        #if ($ret == 256) {  # kill every subprocess
        #    kill 9 => $$; }
        # TODO find better solution (simply ctrl-z ?)

        # TODO do something with audio files, like tagging, cover etc. 
        # http://search.cpan.org/~szabgab/WebService-GData-0.06/lib/WebService/GData/YouTube.pm

        $n++;
    }
    
}
