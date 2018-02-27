#!/bin/csh

#ncea /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2014/CMORPH_V0.x_0.25deg-3HLY_20140[89]*.nc \
#     /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2014/CMORPH_V0.x_0.25deg-3HLY_201410*.nc \
#     /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2014/CMORPH_V0.x_0.25deg-3HLY_2014110[123]*.nc \
#     /glade/scratch/ahijevyc/CMORPH/CMORPH_20140801-1103.nc


# 2015 Spring Experiment
#ncea /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2015/CMORPH_V0.x_0.25deg-3HLY_201505*.nc ./CMORPH_20150501-0531.nc


# 2015 Joaquin
# see /glade/p/work/ahijevyc/ncl/cmorph.ncl


# Appropriate for 2015 West Pacific basin runs
#ncea /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2015/CMORPH_V0.x_0.25deg-3HLY_20150[789]*.nc \
#     /glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2015/CMORPH_V0.x_0.25deg-3HLY_2015100[1-8]*.nc \
#     ./CMORPH_20150701-1008.nc

# Can't remember how I made MPAS plots for 2014. But here is what I did for 2015
#set basin=wp
#foreach h (`seq -w 0 6 240`)
#	ncea -O -v xtime,rainnc,rainc /glade/p/nmmm0031/$basin/20150[7-9]*0/f$h.nc /glade/p/nmmm0031/$basin/20151*0/f$h.nc /glade/p/work/ahijevyc/mpas_plots/$basin/f$h.nc
#end



# To get MPAS comparison, check out work/ahijevyc/mpas_plots and work/ncl/rain_season.ncl
# Also run ~ahijevyc/bin/forecast_links.pl in each mpas date directory
# Then make averages for each forecast hour.
