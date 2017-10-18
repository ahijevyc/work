#!/usr/bin/perl -w

use Date::Calc qw(:all);
use strict;

my $y2 = 2014;
my $m2 = 8;
my $d2 = 1;
my $h2 = 0;
while (defined(my $line = <>)) {
next unless $line =~ / 34, NEQ, /;
my @words = split(",", $line);
my $w = $words[2];
my $y = substr($w,1,4);
my $m = substr($w,5,2);
my $d = substr($w,7,2);
my $h = substr($w,9,2);
print "y=$y m=$m d=$d h=$h ";
my ($Dd,$Dh,$Dm,$Ds) = Delta_DHMS($y2,$m2,$d2,$h2,0,0,
                                  $y,$m,$d,$h,0,0);
print "hours=",$Dd*24+$Dh,"\n";
$y2 = $y;
$m2 = $m;
$d2 = $d;
$h2= $h;
}
