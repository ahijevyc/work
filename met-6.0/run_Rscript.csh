#!/bin/csh

module load R # needed for Rscript
module use /glade/p/ral/jnt/MET/MET_releases/modulefiles
module load met

set year=2012-2014
set year=2017
set dir=/glade/p/work/ahijevyc/met-6.0
setenv MET_BUILD_BASE /glade/p/ral/jnt/MET/MET_releases/met-6.0
setenv RSCRIPTS_BASE $MET_BUILD_BASE/scripts/Rscripts
set R=$RSCRIPTS_BASE/plot_tcmpr.R
set config=plot_tcmpr_config.R
set lead=0,12,24,36,48,60,72,84,96,108,120,132,144,156,168,180,192
#set lead=0,12,24,36,48,72,96,120 # subset for Mike Fiorino's plot comparison
set amodel="MPS3,MPAS"
set modeldiffs="GFSO-MPAS,MPAS-MPS4,GFSO-MPS4,EGRR-MPAS"
set basins="WP AL EP"

if ("$basins" =~ *WP* && "$amodel" =~ *EGRR*) then
	echo EGRR (UKMET with subjective QC applied to tracker) not available in W Pac
	exit
	# EGRR has no wind information.
endif

# If you get an error about not finding Rscript,
# module load R 
# to run Rscript

set trackertype=tracker# could have "tracker" here to analyze tracker mode or "tcgen"
set outdir=$dir/out/$year
set warmcorestr=_GFDL_warmcore_only # or empty string if you accept all cold core tracks (used for MWR paper)
set tcst="$outdir/MP??_0.500deg_025km_gfdl_origmeshTrue_1.0d_minimum${warmcorestr}.$trackertype.tcst"
set tcst="$tcst $outdir/GFSO_0.250deg_gfdl_origmeshFalse_1.0d_minimum${warmcorestr}.$trackertype.tcst"
#set tcst="$tcst $outdir/GFSO.adeck.tcst" # Use adecks
if ($year =~ "2012-2014") then
	set tcst=$outdir/GFSO_adeck.tcst
endif

#set bmax_wind_thresh=34
set bmax_wind_thresh=0

# 2 fields (track error and wind error)
#foreach dep (AMAX_WIND-BMAX_WIND TK_ERR ABS\(AMAX_WIND-BMAX_WIND\) ALTK_ERR CRTK_ERR)
foreach dep (TK_ERR AMAX_WIND-BMAX_WIND)

	# Boxplot, mean, and median plots of model error. Due to outliers, MEDIAN is robust 
	foreach plot (MEAN)
		set prefix=${plot}_${dep}_${amodel}_ge${bmax_wind_thresh}kt_${year}_$trackertype$warmcorestr
		if (! -s $outdir/$prefix.png) then
			Rscript $R -lookin $tcst -filter "-amodel $amodel -column_thresh bmax_wind ge$bmax_wind_thresh" -series AMODEL $amodel -lead $lead -plot $plot -prefix $prefix -dep $dep -outdir $outdir -save_data $outdir/$prefix.tcst -config $config | tee $outdir/$prefix.log
			# Output text file with mean and upper and lower confidence range.
			# tc_stat -lookin $outdir/$prefix.tcst -job summary -column $dep -by lead -by amodel -out $outdir/$prefix.$dep.summary
		else
			echo found $outdir/$prefix.png. skipping
		endif
		foreach basin ($basins)
			set prefix=${plot}_${dep}_${amodel}_${basin}basin_ge${bmax_wind_thresh}kt_${year}_$trackertype$warmcorestr
			if (! -s $outdir/$prefix.png)then
				# for the paper I forced the axes of AMAX_WIND-BMAX_WIND to be the same for tracker and tcgen (add "-ylim -22,24")
				Rscript $R -lookin $tcst -filter "-amodel $amodel -basin $basin -column_thresh bmax_wind ge$bmax_wind_thresh" -series AMODEL $amodel -lead $lead -plot $plot -prefix $prefix -dep $dep -outdir $outdir -save_data $outdir/$prefix.tcst -config $config | tee $outdir/$prefix.log 
				#Rscript $R -lookin $tcst -filter "-amodel $amodel -basin $basin -column_thresh bmax_wind ge$bmax_wind_thresh -init_end 20161009_00 -init_beg 20160928_12 -init_hour 0,12 -valid_end 20161009_00 -storm_name MATTHEW" -series AMODEL $amodel -lead $lead -plot $plot -prefix $prefix -dep $dep -outdir $outdir -save_data t -config $config -no_ee # subset for Matthew and Mike Fiorino comparison

			else
				echo found $outdir/$prefix.png. skipping
			endif
		end
	end

	if (0) then
		# Boxplot, mean, and median plots of Differences between model errors. just do MEAN
		foreach plot (BOXPLOT MEAN )
			set prefix=model_diff_${plot}_${dep}
			if (! -s $prefix.png) Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel" -series AMODEL $modeldiffs -lead $lead -plot $plot -prefix $prefix -dep $dep
			foreach basin ($basins)
				set prefix=model_diff_${plot}_${dep}_$basin
				if (! -s $prefix.png) Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel -basin $basin" -series AMODEL $modeldiffs -lead $lead -plot $plot -prefix $prefix -dep $dep
			end
		end
	endif



	# relative performance (can define thresholds)
	if (0) then 
		set plot=RELPERF
		if ($dep == TK_ERR) then
			# meaningful differences in track error by lead time
			set rp_diff=">=10,>=20,>=30,>=40,>=50,>=60,>=70,>=80,>=90,>=100,>=100,>=100"
		else
			# meaningful differences in max wind error by lead time
			set rp_diff=">=5"
		endif
		set prefix=${plot}_${dep}
		Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel" -lead $lead -plot $plot -prefix $prefix -dep $dep -rp_diff $rp_diff
		foreach basin ($basins)
			set prefix=${plot}_${dep}_$basin
			Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel -basin $basin" -lead $lead -plot $plot -prefix $prefix -dep $dep -rp_diff $rp_diff
		end
	endif


	# Rank plots - try to list each one first.
	if (0) then 
		set plot=RANK
		foreach model (GFSO,MPAS,MPS2 MPAS,GFSO,MPS2 MPS2,GFSO,MPAS)
			set model1=`echo $model|cut -c 1-4`
			set prefix=${plot}_${dep}_${model1}
			Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel" -lead $lead -plot $plot -prefix $prefix -dep $dep -series AMODEL $model
			foreach basin ($basins)
				set prefix=${plot}_${dep}_${model1}_$basin
				Rscript $R -lookin $dir/$tcst -filter "-amodel $amodel -basin $basin" -lead $lead -plot $plot -prefix $prefix -dep $dep -series AMODEL $model
			end
  		end
	endif
end
