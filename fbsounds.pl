#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use URI::Encode;
use Getopt::Long;

my $ua  = LWP::UserAgent->new;
my $uri = URI::Encode->new( { encode_reserved => 0 } );
my $json = JSON->new->allow_nonref;


sub usage_string {
    print "Usage: " . $0 . " -id <facebook-id>  -o <output-dir>  -f <audio-format>  -q <audio-quality>\n";
    exit(1);
}

sub dbg {
    print "DEBUG: " . $_[0] . "\n";
}

# example groups

# the29nov films
#my $group = "113397788684941";
# the29nov core
#my $group = "108775282491150";

# facebook group or site
my $group;

# output directory, default cwd
my $outputDir = ".";

# audio format
my $audioFormat = "aac";

# audio quality
my $audioQuality = "320K";

GetOptions ("id=s"      => \$group,
            "o=s"       => \$outputDir,
            "f=s"       => \$audioFormat,
            "q=s"       => \$audioQuality)
or die("Error in command line arguments\n");

# we need at least a target
if (!(defined $group)) { usage_string(); }

# generated using http://awpny.com/how-to-facebook-access-token/
my $access_token = "574534595973161%7CPxhPG_ibsiompEEnGH5g-bQBeh0";

# entries per page
my $limit = 100;

# where the links go
my @link_array;


########### ENTRY POINT ############

# first page
my $start_url = "https://graph.facebook.com/$group/feed?fields=link&access_token=$access_token&limit=$limit";


my $fbName = fb_name($group);
print "\nGetting links for \"$fbName\" ...\n\n";

# get the video links
get_links($start_url);

print "\n";

# download and convert files
download_vids(@link_array);

print "Done.\n";    # and we're done

####################################


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
    
    if ($res->is_success) {
        
        my $decoded = decode_json($res->content);
        return $decoded->{name};
        
    } else {
        print $res->status_line . "\n";
        print("\nFailed to get name from facebook id\n");
        exit(1);
    }
}


# check if link is downloadable
sub qualifies {
    
    my $candidate = $_[0];
    my $res = 0;
    
    # maybe in the future we will be able to download soundcloud links too
    
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
        
        my $decoded = decode_json($res->content);
        
        foreach my $d (@{ $decoded->{data} }) {

            my $link = $d->{link};
            if (defined $link && qualifies($link)) {
                
                #file_append($link);
                
                # add to download queue
                push(@link_array, $link);
                
                # inform of progress
                print "Links: $#link_array\r";
                
                # debug
                #print $link . "\n";
            }
        }
        
        my $next = $uri->encode($decoded->{paging}->{next});
        
        if (defined $next) {
            
            # again with next page
            get_links($next);
        }

    # request failed
    } else {
        print $res->status_line . "\n";
		exit(1);
    }
}

# download and convert all videos
sub download_vids {
    
    # constructed youtube-dl call from command-line options
    
    foreach my $vid_link (@_) {
        system("youtube-dl -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"");
    }
    
}
