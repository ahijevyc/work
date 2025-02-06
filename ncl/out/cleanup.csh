#!/bin/csh

# Input
# arguments are filenames
# these were written by ncl/ACC.multi.ncl

# Output 
# sorted, no duplicates
# header on first line (line with "init_date" in it) 

# Usage:
# cleanup.csh ACC.*.txt


set t=m22idx

if (-e $t) then
    echo found temporary file $t. exiting
    exit
endif
foreach f ($*)
    set n=`grep init_date $f | wc -l`
    # If there are two init_date lines
    if ($n == 2) then
        ls -l $f
        # split it and keep the 2nd one
        split -n 2 $f
        rm xaa
        mv xab $f
    endif
    continue
    sort $f | uniq > $t
    if ($status != 0) exit
    grep init_date $t > $f
    if ($status != 0) exit
    grep -v init_date $t >> $f
    if ($status != 0) exit
end
# assume everything is okay at this point and remove temporary file
rm $t
