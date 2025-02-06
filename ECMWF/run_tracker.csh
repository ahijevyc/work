#!/bin/csh

set ymdh="$1"
set workdir=/glade/scratch/ahijevyc/ECMWF
set ymd=`echo $ymdh | cut -c1-8`
set h=`echo $ymdh | cut -c9-10`
cd $workdir/$ymdh
mkdir -p gfdl_tracker
cd gfdl_tracker
cnvgrib -g21 ../0p25${ymdh}_pl.grb fort.11
cnvgrib -g21 ../0p25${ymdh}_sfc.grb t
cat t >> fort.11
rm t
grbindex.exe fort.11 fort.31
touch fort.14
set nt=`wgrib fort.11|grep ":500 mb:" | grep ":HGT:" | wc -l`
set dmin=360
set minutes=`expr $nt \* $dmin - $dmin`
create_fort.15 `seq -w -s ' ' 0 $dmin $minutes`

~ahijevyc/bin/wget_tcvitals.csh $ymd $h fort.12

# Extract date/time substrings for namelist
set bcc=`echo $ymdh|cut -c1-2`
set byy=`echo $ymdh|cut -c3-4`
set bmm=`echo $ymdh|cut -c5-6`
set bdd=`echo $ymdh|cut -c7-8`
set bhh=`echo $ymdh|cut -c9-10`

# Run GFDL vortex tracker
cat <<NL > namelist
&datein
inp%bcc=$bcc,
inp%byy=$byy,
inp%bmm=$bmm,
inp%bdd=$bdd,
inp%bhh=$bhh,
inp%model=21,
inp%lt_units='hours',
inp%file_seq='onebig',
inp%modtyp='global',
inp%nesttyp='fixed'
/
&atcfinfo
atcfnum=0,
atcfname=' EMX',
atcfymdh=$ymdh,
atcffreq=600
/
&trackerinfo
trkrinfo%westbd=-180,
trkrinfo%eastbd=180.,
trkrinfo%northbd=60,
trkrinfo%southbd=0,
trkrinfo%type='tracker',
trkrinfo%mslpthresh=0.01
trkrinfo%v850thresh=3.0,
trkrinfo%gridtype='global',
trkrinfo%contint=100.0,
trkrinfo%out_vit='y'
/
&phaseinfo
phaseflag='n',
phasescheme='both'
wcore_depth=1.0
/
&structinfo
structflag='n',
ikeflag='n'
/
&fnameinfo
gmodname=' ec',
rundescr='t${h}z',
atcfdescr=''
/
&waitinfo
use_waitfor='n'
/
&verbose
verb=3
/

NL

~ahijevyc/bin/tracker.exe < namelist > log

# plot tracks
~ahijevyc/bin/process-plot.sc $ymdh ecmwf

