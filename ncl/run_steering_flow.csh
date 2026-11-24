#!/bin/csh

ncl nc_output=True 'stormname="Joaquin"' storm_heading=45 storm_speed=3.2 lat0=24.3 lon0=-74.3 force_new=True fhr=000 rx=2.5 pbot=850 ptop=200 'file_ncl="/glade/scratch/ahijevyc/NARR/merged_AWIP32.2015100300.3D"' 'ensmember="JOAQUIN2015"' /glade/work/ahijevyc/ncl/steering.ncl
