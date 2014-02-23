#!/bin/bash

# check for root rights

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root";
   exit 1;
fi

# default answers to questions
PERL_MM_USE_DEFAULT=1;

# without this, LWP::UserAgent doesn't work on linux
if [ `which apt-get` ]; then
	sudo apt-get install libssl-dev;
else 
	# it failed at least on linux without libssl-dev
	if [ `uname` == "Linux" ]; then
		echo "This is Linux and apt-get is not installed, which is needed for libssl-dev, which is needed for LWP::Protocol::https. Exiting.";
		exit 1; 
	fi
fi

# install perl dependency modules
sudo perl -MCPAN -e 'install JSON, Term::ANSIColor, LWP::UserAgent, LWP::Protocol::https, Getopt::Long, URI::Encode;';

echo 0