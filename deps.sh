#!/bin/bash

# check for root

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# install perl dependency modules

PERL_MM_USE_DEFAULT=1; 
sudo perl -MCPAN -e 'install JSON, Term::ANSIColor, LWP::UserAgent, Getopt::Long, URI::Encode;'
