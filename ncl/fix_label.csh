#!/bin/csh

set x=210
set y=51.5
if ("$1" =~ *.central.*) then
	set x=200
	set y=49.5
endif
if ("$1" =~ *.east.*) then
	set x=206
	set y=49.5
endif
convert -pointsize 28 -background white -fill black label:'sfc. wind barb' miff:- | composite -geometry +$x+$y - $1 $1~
if ($status == 0) mv $1~ $1
