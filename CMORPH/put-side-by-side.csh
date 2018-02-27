#!/bin/csh

cd /glade/p/work/ahijevyc/mpas_plots/wp
foreach f (rain6h.f???-f???.png)
	set fh=`echo $f | cut -c9-11`
	set fh=`echo $fh \/ 6 % 4 + 1|bc`
	set out=CM_$f
	convert +append /glade/p/work/ahijevyc/CMORPH/CMORPH_20150701-1008.00000$fh.png $f $out 
	mogrify -trim +repage $out
end
