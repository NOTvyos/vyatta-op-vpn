#!/usr/bin/perl -w
#
# Module: gen_local_rsa_key.pl
# 
# **** License ****
# Version: VPL 1.0
# 
# The contents of this file are subject to the Vyatta Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.vyatta.com/vpl
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2006, 2007 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: 2007
# Description: Utility to generate a local RSA key.
# 
# **** End License ****
# 

use strict;
#use warnings;
use lib "/opt/vyatta/share/perl5/";

use VyattaVPNUtil;


# Defaults
my $bits = 2192;
my $device = "/dev/random";

if ($#ARGV > 1) {
    die "Usage: gen_local_rsa_key.pl <bits> <device>\n";
}
$bits = $ARGV[0] if $#ARGV >= 0;

#
# The ipsec newhostkey command seems to support up to 
# 20000 bits for key generation, but xorp currently
# can't handle a line that long when entered in the 
# config.  Xorp seems to be able to handle keys generated
# with up to 5840 bits.
#
my ($bits_min, $bits_max) = (16, 4096);

if ($bits > $bits_max) {
    die "bits must be <= $bits_max\n";
}
if ($bits < $bits_min) {
    die "bits must be >= $bits_min\n";
}
if ($bits % 16 != 0) {
    die "bits=$bits is not a multiple of 16\n";
}
$device = $ARGV[1] if $#ARGV >= 1;
unless (-r $device) {
    die "invalid random number device $device\n";
}

my $local_key_file = VyattaVPNUtil::rsa_get_local_key_file();

my ($cmd, $rc);

if (-r $local_key_file) {
    $| =1;   # force a flush
    print "A local RSA key file already exists and will be overwritten\n";
    print "<CTRL>C to exit:  ";
    my $loop = 9;
    while ($loop) {
	print "\b$loop";
	sleep 1;
	$loop--;
    }
    print "\n";
} else {
    my ($dirpath) = ($local_key_file =~ m#^(.*/)?.*#s);
    $cmd = "mkdir -p $dirpath";
    $rc = system($cmd);
    if ($rc != 0 ) {
	die "Cannot mkdir $dirpath $!\n";
    }
}

$cmd = "/usr/sbin/ipsec newhostkey --output $local_key_file --bits $bits";
#
# The default random number generator is /dev/random, but it will block 
# if there isn't enough system activity to provide enough "good" random
# bits.  Try /dev/urandom if it's taking too long.
#
$cmd .= " --random $device";

print "Generating rsa-key to $local_key_file\n";
VyattaVPNUtil::vpn_debug $cmd;
$rc = system($cmd);
if ($rc != 0) {
    die "Can not generate RSA key: $!\n";
}

my $file_pubkey = VyattaVPNUtil::rsa_get_local_pubkey($local_key_file);
if ($file_pubkey ne 0) {
    print "\nYour new local RSA key has been generated\n";
    print "The public portion of the key is:\n\n$file_pubkey\n\n";
    $cmd = "ipsec auto --rereadall 2> /dev/null";
    VyattaVPNUtil::vpn_debug $cmd;
    system $cmd;
    exit 0;
}
die "Can not find pubkey\n";