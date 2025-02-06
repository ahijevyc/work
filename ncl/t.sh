#!/bin/sh 

# tried csh but had to backslash escape all the quotes and wildcards. . . sheesh.

# track-abby2.ncl is a little faster than track-abby.ncl. This time test shows that whichever
# script runs 2nd is fastest. Must be a cache thing. 
time ncl 'DATAdir="/glade/scratch/fossell/ADCIRC/IKE/wrf/mem_1/wrfout_d03_2008-09-??_0[06]:00:00 /glade/scratch/fossell/ADCIRC/IKE/wrf/mem_1/wrfout_d03_2008-09-??_1[28]:00:00"' Is=92 Js=104 track_wrf.ncl
