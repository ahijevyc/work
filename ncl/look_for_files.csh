#!/bin/csh
#
# Find old diagnostic files and set NCL scripts in motion.
# 
# Batches of new diagnostic files are plotted every 10 minutes.
#
# Usage:
#    look_for_files.csh [yyyymmddhh] [-h] [-p project] [-w workdir] [-m mmin]
#
#    [yyyymmddhh] (optional) is the 0 UTC date we wish to process.
#    Current 0 UTC date is the default.
#
#    [-p project] (optional) where project is the project name.
#    Examples include
#    hwt2017, hur15us, spring_exp, hur15ep, hur15al, and hur15.
#
#    [-w workdir] (optional) 
#    Examples include hwt2017, us, ep, al, and wp.
#
#    [-m mmin] (optional)
#       This option defines the # of minutes to wait after the last
#       modification time of a diagnostics file in order to plot it.
#       By waiting -m minutes (4, by default) we almost guarantee the 
#       files are completely written before plotting. We used to 
#       wait for a particular file size but that changes too 
#       frequently to be helpful.
#
# Reads:
#   $EXEDIR/ncl/$project.plots.txt for list of plot types
#
# Calls:
#    run_field_and_contour_ncl.csh
#       sets up and runs field_and_contour.ncl to 
#       plot diagnostic fields
#
#    SHARPpy_skewts.py
#       plots skewT of *.snd files
#
#    to_server.csh
#       rsync diagnostic field plots to web server
#       (used to tar them first but not anymore)
#       called repeatedly after many delays to 
#       accommodate delayed runs and reruns
#
#    run_mpas_to_latlon.csh
#       Interpolates diagnostic files to lat/lon 
#       for GFDL vortex tracker 
#
#    run_mpas_ll_GRIB1.csh
#       runs GFDL vortex tracker on lat/lon files
#       plot tracks and send to web server
#
#    run_fcst-init.sh
#       calculate bias, squared error, and ACC for 
#       all forecasts valid at this time.
#       Run on MPAS and maybe GFS from 2 days earlier
#


set cdate=`date -u +%Y%m%d00`
set project=hur15
set EXEDIR=/glade/work/mpasrt/tc2016
set mmin=4
set workdir=wp
while ("$1" != "")
    if ("$1" =~ 20??????00) set cdate="$1"
    if ("$1" == "-h") then
        echo "Usage: look_for_files.csh [yyyymmddhh] [-h] [-p project] [-w workdir] [-m mmin]"
        exit 1
    endif
    if ("$1" == "-p") then
        shift
        set project="$1"
    endif
    if ("$1" == "-m") then
        shift
        set mmin="$1"
    endif
    if ("$1" == "-w") then
        shift
        set workdir="$1"
    endif
    shift
end

# Default diagnostics file prefix and forecast length in hours
set diag_prefix=diag # diag or diagnostics
set maxhour=120
# Change for hur15 project
if ($project =~ hur15* || $project == "uni") then
    set diag_prefix=diag
    set maxhour=240
endif
set idir=/glade/scratch/mpasrt/$workdir/$cdate
set year=`echo $cdate|cut -c1-4`
set month=`echo $cdate|cut -c5-6`
set day=`echo $cdate|cut -c7-8`
set hour=`echo $cdate|cut -c9-10`
set first_file=$diag_prefix.$year-$month-${day}_$hour.00.00.nc

# Avoid running out of 6:00 hour wall clock after late mpas start. 
# Sleep until the first diagnostics file exists. . .
while (! -s $idir/$first_file)
    date
    echo 1st diagnostic file does not exist. Sleeping...
    sleep 60
end

set fdate=`/glade/u/home/ahijevyc/bin/geth_newdate $cdate $maxhour`
set year=`echo $fdate|cut -c1-4`
set month=`echo $fdate|cut -c5-6`
set day=`echo $fdate|cut -c7-8`
set hour=`echo $fdate|cut -c9-10`
set final_file=$diag_prefix.$year-$month-${day}_$hour.00.00.nc
set diags2plot=$idir/${project}$cdate.2plot.txt # added $project$cdate to keep separate from other runs
setenv plot_types_path $EXEDIR/ncl/$project.plots.txt

umask 2
mkdir -p $idir/plots
set batchfile=$idir/plots/look_for_files.batchfile
cat <<END > $batchfile
#!/bin/csh
#PBS -A P64000101
#PBS -N plots.$workdir.$cdate
#PBS -l walltime=06:00:00
#PBS -q share
#PBS -l select=1:mpiprocs=1
#PBS -j oe
#PBS -M ahijevyc@ucar.edu
#PBS -m abe

cd $idir
echo Now in $idir.
umask 2

echo Every 15 min, plot a batch of completed diagnostic files as you wait for final file to exist. . .
while (! -e $final_file)
    date
    echo no $final_file yet. plotting diagnostic files last modified more than $mmin min ago
    # write filenames to a file, substituting spaces for newlines.
    # Removed final size requirement to allow for varying sizes. 
    # Added -mmin +$mmin (last modify $mmin minutes ago)
    find . -maxdepth 1 -name "$diag_prefix.*.nc" -mmin +$mmin | tr '\n' ' ' | tee $diags2plot
    # This list of files is quoted, and given to script that executes a bunch of NCL plots.
    if (-s $diags2plot) then
        $EXEDIR/run_field_and_contour_ncl.csh -p $project -w $workdir -t $plot_types_path $cdate --fname_pattern "\`cat $diags2plot\`"
        $EXEDIR/to_server.csh -p $project -t $plot_types_path $cdate
    endif
    echo waiting 10 minutes...
    sleep 600
end

echo \`date\` Making skewTs in background...
# needed for skewTs
module load python
ncar_pylib
$EXEDIR/SHARPpy_skewts.py -p $project -w $workdir $cdate >& $idir/skewts.out &


# Plot final batch of diagnostic files. Wait a minute just to ensure last file is finished being written.
find . -maxdepth 1 -name "$diag_prefix.*.nc" | tr '\n' ' ' | tee $diags2plot
grep $final_file $diags2plot > /dev/null # Sanity check
# Tried escaping status so it isn't always zero
if (\$status != 0) then
    echo final file $final_file not in list of files to plot! Problem.
endif
echo \`date\` waiting 60s before plotting last batch...
sleep 60
$EXEDIR/run_field_and_contour_ncl.csh -p $project -w $workdir -t $plot_types_path $cdate --fname_pattern "\`cat $diags2plot\`"

date
$EXEDIR/to_server.csh -p $project -t $plot_types_path $cdate

echo \`date\` Interpolating to lat-lon...
uname -a
~ahijevyc/bin/run_mpas_to_latlon.csh $cdate -w $workdir >& $idir/run_mpas_to_latlon.out

date
echo Submitting tracker job...
$EXEDIR/run_mpas_ll_GRIB1.csh $cdate -w $workdir >& $idir/run_mpas_ll_GRIB1.out

# Most plots are finished in 900 sec but some take much longer. check one more time in a couple hours.
sleep 7200 
date
$EXEDIR/to_server.csh -p $project -t $plot_types_path $cdate

END
# Avoid qsub command not found
/opt/pbs/default/bin/qsub $batchfile

