#!/bin/bash


# check for root rights
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root";
   exit 1;
fi


# without this, LWP::UserAgent doesn't work on linux
if [[ `uname` == "Linux" ]]; then
	if [[ `which apt-get` ]]; then
		sudo apt-get install libssl-dev;
	else 
		# at least on Linux it failed without libssl-dev
		echo "This is Linux and apt-get is not available, which is needed for libssl-dev, which is needed for LWP::Protocol::https. Exiting.";
		exit 1;
	fi
fi


# default answers to questions
PERL_MM_USE_DEFAULT=1;

# install perl dependency modules
sudo perl -MCPAN -e 'install JSON, Term::ANSIColor, LWP::UserAgent, LWP::Protocol::https, Getopt::Long, URI::Encode;';

exit 0;