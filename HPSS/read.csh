#!/bin/csh
alias stats /glade/u/home/ahijevyc/bin/stats -h $*

# See how many bytes are in HPSS under /WRFRT/MPASRT/.

# Do this first as user ahijevyc (or an account with HSI access)
# 
foreach subdir (2013 2014 2015 2016 2017 GFSsf)
  hsi ls -lR /WRFRT/MPASRT/$subdir >& WRFRT.MPASRT.$subdir
end
#
foreach subdir (15KM 15KM-RERUN GFS VARIABLE_AL VARIABLE_EP_rerun VARIABLE_WP)
  hsi ls -lR /WRFRT/MPASRT/2014/$subdir >& WRFRT.MPASRT.2014.$subdir
end
# This creates a bunch of long file listings for each subdirectory.
# You can grep out lines with 'ncar' in them to isolate the files.
# Then awk grab the 5th column (file size).
# Then add them up.
# You can add an -h option to stats to make the output human-readable.
# In other words, large numbers will be written as smaller
# numbers with a metrix prefix. For example 5000000000000 = 5.00 T
#


# Show total bytes in each WRFRT* directory
foreach f (WRFRT.MPASRT.2??? WRFRT.MPASRT.GFSsf)
    printf "$f "
    grep ncar $f|awk '{print $5}' | stats | grep sum
end
echo
echo
foreach f (WRFRT.MPASRT.2014.*)
    printf "$f "
    grep ncar $f|awk '{print $5}' | stats | grep sum
end
echo
echo
foreach f (mpas.output. diag history tomjr GFS)
    printf "$f "
    cat WRFRT.MPASRT.2??? WRFRT.MPASRT.GFSsf | grep ncar | grep $f | awk '{print $5}' | stats | grep sum
end
