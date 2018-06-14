#!/bin/csh
module use /glade/p/ral/jnt/MET/MET_releases/modulefiles
module load met
 
set force_new=0
if ("$1" == "-f") then
	set force_new=1
	shift
endif

# copied from old/hits_column_excel.csh
#
# Filter matched track times by fh, model vmax, and obs vmax. 
#
# This script reads all the matched tracks and 
# creates $outdir/$year/$m_0.500deg_025km_gfdl_origmeshTrue_1.0d_minimum.tcst with tc_pairs.
# It filters with tc_stat by forecast hour, model and observed wind speed vmax.
#
# count rows in -dump_row output
# and import into upper left 2x2 matches portion of 3x3 contingency table.
#
# matched false alarms come from here and are added to unmatched.
# unmatched false alarms come from run_get_all_vitals.pro and ~ahijevyc/bin/filter_nomatches.pl
# unmatched misses come from find_matching_model_track.pro and ~ahijevyc/bin/filter_nomatches.pl
#
# Process with ~/bin/first_common_time_etc.csh to get cyclogenesis timing

# MPAS = global 15km
# MPS2 = al  60-15km
# MPS3 = wp  60-15km
# MPS4 = ep  60-15km

set year=2017
set init_beg="${year}0801"
set init_end="${year}1103"
set mps="MPAS MPS2 MPS3 MPS4 GFSO"
set gfs_gs=0.500deg
if ($year == 2014) set mps="MPS4 MPAS GFSO" # just uniform and EP in 2014
if ($year == 2015) then
	# Compare GFS to wp using same date range.
	set init_beg="${year}0701" # wp available 20150701
	set mps="MPS3 GFSO" # 3 basins in 2015

	# Compare GFS to ep or al. ep and al start 20150718
	set init_beg="${year}0718" 
	set mps="MPS4 GFSO" # 3 basins in 2015

	set init_end="${year}1008" # al, ep, and wp last day is 20151008 
	set gfs_gs=0.250deg
endif
if ($year == 2016) then
	set init_beg="${year}0629" # wp available 20160629-20161031, ep 20160901-20160930, and al 20160825-20161024
	set init_end="${year}1031" 
	set mps="MPS2 MPS3 MPS4 GFSO" # 1-3 basins in 2016
	set mps="MPS3 GFSO" # 
	set gfs_gs=0.250deg
endif
if ($year == 2017) then
    set init_beg="${year}0801"
	set init_end="${year}1031" 
	set mps="MPS3 MPAS GFSO" #
	set gfs_gs=0.250deg
endif 
if ($1 =~ [MG]???) set mps=$1
set meshdetails=_0.500deg_025km_gfdl_origmeshTrue_1.0d_minimum_GFDL_warmcore_only

set outdir=out # out or test

foreach m ($mps)
	if ($m == "GFSO") set meshdetails=_${gfs_gs}_gfdl_origmeshFalse_1.0d_minimum_GFDL_warmcore_only
	set trackertype=tcgen# you could have "tracker" or "tcgen" here
	set md=$outdir/$year/$m$meshdetails.$trackertype
	set dats="/glade/p/work/ahijevyc/tracking_gfdl/adeck/*/$trackertype/a??[0-6]?$year$meshdetails"
	# if .dat or .tcst file doesn't exist or force_new is true or most recent file is not $md.dat then recreate .dat file and rerun tc_pairs.
	if (! -s $md.dat || ! -s $md.tcst || $force_new || `ls -tr1 $dats $md.dat | tail -n 1` != $md.dat) then
		# Do the model filtering now yourself instead of waiting for tc_stat later.
		# I don't think this screws up my run_Rscript.csh program.
		cat $dats | grep ", 03, $m," > $md.dat
		echo "reading from $dats"
		if (! -s $md.dat) then
			echo "no lines for $m in $dats? exiting"
			exit
		endif

		# Do I want GFS from the working a-deck (called AVNO). not my tracker?
		# If you do, activate this if-block.
		if ($m == "GFSO" && 0) then
			# Replace "_origmeshFalse_" with "_adeck_" in variable $md and in file name.
			set md=$outdir/$year/$m.adeck
			# grep AVNO and HWRF from ADECKs. -h suppresses prefixing of file names on output
			#grep -h AVNO /glade/p/work/ahijevyc/atcf/a??[0-6]?$year.dat > $md.dat
			egrep -h "AVNO|HWRF|EGRR|GFSO" /glade/p/work/ahijevyc/atcf/hurricanes.ral.ucar.edu/repository/data/adecks_open/a??[0-6]?$year.dat > $md.dat
		endif
		
		tc_pairs -adeck $md.dat -bdeck ../atcf/b??[0-6]?$year.dat -config TCPairsConfig -out ${md}
		column -t $md.tcst > $md.x
		if ($status == 0) mv $md.x $md.tcst
		# Used to have this in else-block below if-block about $m=="GFSO" and using a-deck.
		#   Why not filter all new .tcst files for calendar dates? Why just non-GFSO or non-adeck?
		# filter calendar dates - output to temp file cause you can't filter in-place (it will erase input file)
		# Filter only if you don't use offical a-deck. (again, as I asked above why? I can't recall why I did this at one time. switched Oct 11 2016).
		tc_stat -lookin $md.tcst -job filter -init_beg $init_beg -init_end $init_end -dump_row $md.filterdate
		if ($status == 0) mv -v $md.filterdate $md.tcst
	endif

	foreach wnd (34 64 ) # 34 or 64 (not ge34 or ge64)
		# Global first, then basins
		foreach b (WP AL)
            # Isolate basin of interest for speed. We read into memory and purge from memory the entire $md file 1000 times. Make it as small as possible.
            set basin_cmd="-basin $b"
            if ($b == "global") set basin_cmd='' # if global don't use "-basin" in command line. Tried empty set [] like in params file, but no luck.
            # johnhg suggested using a comma separated list with the -basin option, i.e. -basin AL,WP,CP,EP,IO,SH
	        set md=$outdir/$year/$b.$m$meshdetails.$trackertype
		    tc_stat -lookin $outdir/$year/$m$meshdetails.$trackertype.tcst -job filter $basin_cmd -dump_row $md.tcst

			# Tempting to do every 3 hours because GFS and MPAS are at least 3-hrly. But best tracks are 6-hrly and
			# are undefined at forecast hours 3, 9, 15, 21, etc. 
			# for my_tracker start at 6h . For GFDL start at 0h.
			echo $init_beg-$init_end $m $b V=${wnd}kt $md
			echo "2x2 table and FAs on matched tracks (FAs on unmatched tracks from filter_nomatches.pl)"
			echo "element:  YY       YM       YN       MY       MM       MN"
			echo "hr   Fcst>=V; Fcst>=V; Fcst>=V;  Fcst<V;  Fcst<V;  Fcst<V;"
			echo "      Obs>=V    Obs<V   Obs=NA   Obs>=V    Obs<V   Obs=NA"  
			foreach fh (`seq -w 0 6 240`)
				#
				# model >= wnd, obs >= wnd
				set out1 = $outdir/$year/model.ge$wnd.obs.ge$wnd.$fh.`basename $md`.tcst
                # Used to filter by -init_beg, -init_end but these were filtered in the if-block above.  Maybe delete this commented line if everything works out okay.
                # Also filtered out basin first to speed up things. -ahijevyc Nov 6, 2017
                # Tried eliminating -amodel $m, but w/o editing default tc_pairs config file, one ends up with MPSI in addition to MPS3 in row-dump output file.
                # Change the default setting of interp12 from REPLACE to NONE. But with each version upgrade I don't trust myself
                # to remember this. So keep the -amodel $m filter below for safety.  It has something to do with ATCF ID ending with "2" or "3".
                #
                #if (! -e $out1 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m $basin_cmd -lead $fh -column_thresh amax_wind ge$wnd -column_thresh bmax_wind ge$wnd -init_beg ${init_beg} -init_end ${init_end} -dump_row $out1
				if (! -e $out1 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind ge$wnd -column_thresh bmax_wind ge$wnd -dump_row $out1

				# model >= wnd, obs < wnd
				set out2 = $outdir/$year/model.ge$wnd.obs.lt$wnd.$fh.`basename $md`.tcst
				if (! -e $out2 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind ge$wnd -column_thresh bmax_wind lt$wnd -dump_row $out2

				# model >= wnd, obs = NA - In METv4.1 I used -column_str bmax_wind NA. In met-5.2 -column_str bmax_wind NA doesn't match anything (and -column_trhresh bmax_wind NA matches everytyhing).
				set out3 = $outdir/$year/model.ge$wnd.obs.eq.NA.$fh.`basename $md`.tcst
				if (! -e $out3 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind ge$wnd -column_str blat -9999 -dump_row $out3 

				# model < wnd, obs >= wnd
				set out4 = $outdir/$year/model.lt$wnd.obs.ge$wnd.$fh.`basename $md`.tcst
				if (! -e $out4 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind lt$wnd -column_thresh bmax_wind ge$wnd -dump_row $out4

				# model < wnd, obs < wnd
				set out5 = $outdir/$year/model.lt$wnd.obs.lt$wnd.$fh.`basename $md`.tcst
				if (! -e $out5 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind lt$wnd -column_thresh bmax_wind lt$wnd -dump_row $out5

				# model < wnd, obs = NA - See comment above for matching "NA"
				set out6 = $outdir/$year/model.lt$wnd.obs.eq.NA.$fh.`basename $md`.tcst
				if (! -e $out6 || $force_new) tc_stat -lookin $md.tcst -job filter -amodel $m -lead $fh -column_thresh amax_wind lt$wnd -column_str blat -9999 -dump_row $out6

				printf "$fh"
				foreach out ($out1 $out2 $out3 $out4 $out5 $out6)
					column -t $out > $out.x
					if ($status == 0) mv $out.x $out
					printf '%9d' `grep -v "^VERSION" $out | wc -l`
				end
				echo
			end # fh forecast hour
		end # b basin
	end # wnd wind threshold
end # m model


echo See Nov 17 2016 email from John HG about how to replicate the out3 and out6 python scripts I wrote as a STOPGAP measure until MET-5.2 can filter NA. He said to use -column_str blat -9999

