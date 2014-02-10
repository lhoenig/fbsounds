#!/usr/bin/env perl -w

use strict;
use warnings;

use constant DEBUG => 0;

$SIG{'INT'}  = 'kill9';  #  enhances user experience a bit

use JSON;
use LWP::UserAgent;
use URI::Encode;
use Getopt::Long;
use Term::Size::Any qw(chars);
use Data::Dumper;
use Term::ANSIColor;

local $| = 1;   # autoflush stdout

my $ua  = LWP::UserAgent->new;
my $uri = URI::Encode->new( { encode_reserved => 0 } );
my $json = JSON->new->allow_nonref;


sub usage_string {
    print "Usage: " . $0 . " -id <facebook-id>  -o <output-dir>  -f <audio-format>  -q <audio-quality>\
    \rSee youtube-dl -h for available formats and qualities.\
    \rDefault output format is aac and quality 320K, if omitted.\n";
    exit(1);
}


sub dbg {
    print "DEBUG: " . $_[0] . "\n";
}

sub kill9 {
    kill 'KILL', $$
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

# audio format (youtube-dl)
my $audioFormat = "aac";

# audio quality (youtube-dl)
my $audioQuality = "320K";

# read command line options
GetOptions ("id=s"      => \$group,
            "o=s"       => \$outputDir,
            "f=s"       => \$audioFormat,
            "q=s"       => \$audioQuality)
or die("Error in command line arguments\n");

# we at least need a target
if (!(defined $group)) { usage_string(); }


#
# generated using http://awpny.com/how-to-facebook-access-token/
#
sub get_access_token {
    
    my $req = HTTP::Request->new(GET => "https://graph.facebook.com/oauth/access_token?grant_type=client_credentials&client_id=$_[0]&client_secret=$_[1]");
    my $res = $ua->request($req);
    if ($res->is_success) {
        return $uri->encode((split(/access_token=/, $res->content))[1]);
    } else {
        return 0;
    }

}

# entries per page
my $limit = 100;

# where the links go
my @link_array;





########### MAIN ###############################################################################

# generate token because it changes over time
my $access_token = get_access_token("418233354989018", "f1427b29a382c5d30581b8b3ffe1d201");

# first page
my $start_url = "https://graph.facebook.com/$group/feed?fields=link&access_token=$access_token&limit=$limit";

dbg("Start: " . $start_url) if DEBUG;


my $fbName = fb_name($group);
print "\nGetting links for \"$fbName\" ...\n";


# get the video links
get_links($start_url);

# filter duplicate links
@link_array = keys %{{ map{$_=>1}@link_array}};

print "\n";

# download and convert files
download_vids(@link_array);

print colored("\nDone.\n\n", "yellow");

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
    
    dbg("fb_name: " . $query) if DEBUG;

    if ($res->is_success) {
        
        my $decoded = decode_json($res->content);
        return $decoded->{name};
        
    } else {
        print $res->status_line . "\n\n" . $res->content . "\n";
        print("\nFailed to get name from facebook id\n");
        exit(1);
    }
}


# check if link is downloadable
sub qualifies {
    
    my $candidate = $_[0];
    my $res = 0;
    
    # TODO in the future we will be able to download soundcloud links too
    
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
                print colored("Links: ", "yellow") . colored("$#link_array\r", "bright_blue");
              }
        }
        
        my $next = $uri->encode($decoded->{paging}->{next});
        
        if (defined $next) {
            
            # again with next page, maybe in the future we will do something about deep recursion
            #get_links($next);
        }

    # request failed
    } else {
        print $res->status_line . "\n";
		exit(1);
    }
}


sub progress_line {

    my $cols = chars();    # terminal width
    
    my $max = $_[1] + 1;
    my $msg = colored("\n[==========]", "yellow") . 
              colored(" $_[0] / $max ", "bright_blue") . 
              colored("[==========]" , "yellow") . "\n";
    
    my $len_msg = length($msg);
    
    return $msg;
}


# download and convert all videos
sub download_vids {
    
    my $n = 1;
    foreach my $vid_link (@_) {
        
        # total progress
        print progress_line($n, $#_);
        
        #print "******** VIDEO $n of $#_ ********\n";
        
        # constructed youtube-dl call from cl-options
        system("youtube-dl -x --audio-format $audioFormat --audio-quality $audioQuality -o \"$outputDir/%(title)s.%(ext)s\" \"$vid_link\"");
        $n++;
    }
    
}
