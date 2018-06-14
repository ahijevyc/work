#!/usr/bin/perl -wn 
use strict;

print "load \"/glade/work/ahijevyc/ncl/xtime.ncl\"\n" if $. == 6;
next if /fhour = 0/;
s/\+fhour\+/+fhour_xtime(ff,f)+/;
# change do loop increment from 2 to 1
s/do nf = 0, nfiles-1, *2/do nf = 0, nfiles-1/;
s/do nf = 0, nfiles-1,1/do nf = 0, nfiles-1/;
next if /fhour = fhour/;
print;


