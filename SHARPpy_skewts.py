#!/usr/bin/env python

"""
 Originally Written by: Greg Blumberg (OU/CIMMS) 
 This IPython Notebook tutorial was meant to teach how to directly interact with the SHARPpy libraries using the Python interpreter.
 It reads files into the the Profile object, plots data using Matplotlib, and computes various indices from the data.

 load python and all-python-libs modules before running this
> module load python
> module load all-python-libs
"""

import glob,sys,os,argparse
sys.path.append('/glade/u/home/ahijevyc/lib/python2.7') # For myskewt and mysavfig

# Call this before pyplot
# avoids X11 window display error as mpasrt
# says we won't be using X11 (i.e. use a non-interactive backend instead)
import matplotlib
matplotlib.use('Agg')
import myskewt as skewt # Put after matplotlib.use('Agg') or else you get a display/backend/TclError as user mpasrt.

import matplotlib.pyplot as plt
from mpl_toolkits.basemap import Basemap
import datetime as dt
from subprocess import call # to use "rsync"
from mysavfig import mysavfig
import pdb

from skewx_projection import SkewXAxes
import sharppy
import sharppy.sharptab.profile as profile
import sharppy.sharptab.interp as interp
import sharppy.sharptab.winds as winds
import sharppy.sharptab.utils as utils
import sharppy.sharptab.params as params
import sharppy.sharptab.thermo as thermo
import numpy as np
from StringIO import StringIO

parser = argparse.ArgumentParser(description='Plot skew-Ts')
parser.add_argument('init_time', type=str, help='yyyymmddhh')
parser.add_argument('-w','--workdir', type=str, help="working directory under /glade/scratch/mpasrt/. Ususally a name for MPAS mesh (e.g. 'conv', 'us', 'wp', 'ep', 'al')")
parser.add_argument('-i','--interval', type=int, help='plot interval in hours', default=3)
parser.add_argument('-p','--project', type=str, help='project', default='hur15us')
parser.add_argument('-v','--verbose', action="store_true", help='print more output.')
parser.add_argument('-d','--debug', action="store_true", help='debug mode.')
parser.add_argument('-f','--force_new', action="store_true", help='overwrite existing plots')
parser.add_argument('-n','--nplots', type=int, default=-1, help='plot first "n" plots. useful for debugging')
args = parser.parse_args()

debug = args.debug
force_new = args.force_new
nplots = args.nplots
project = args.project

if debug:
    print args
    pdb.set_trace()
odir = "/glade/scratch/mpasrt/%s/%s/plots"%(args.workdir,args.init_time)
if not os.path.exists(odir):
    os.makedirs(odir)
os.chdir(odir)
if not os.path.exists(args.init_time):
    os.makedirs(args.init_time)
# plot every *.snd file
sfiles = glob.glob("../*.snd")
sfiles.extend(glob.glob("../soundings/*.snd"))
#print sfiles
# cut down number of plots for debugging
sfiles.sort()
if nplots > -1:
    sfiles = sfiles[0:nplots]

def parseGEMPAK(sfile):
    ## read in the file
    data = np.array([l.strip() for l in sfile.split('\n')])
    ## Grab 3rd, 6th, and 9th words
    stidline = [i for i in data if "STID =" in i]
    stid, stnm, time = stidline[0].split()[2:9:3]
    slatline = [i for i in data if "SLAT =" in i]
    slat, slon, selv = slatline[0].split()[2:9:3]
    ## necessary index points
    start_idx = np.where(data == "PRES      HGHT     TMPC     DWPC     DRCT     SPED")[0][0] + 1
    finish_idx = len(data)
    ## put it all together for StringIO
    full_data = '\n'.join(data[start_idx : finish_idx][:])
    sound_data = StringIO( full_data )
    ## read the data into arrays
    p, h, T, Td, wdir, wspd = np.genfromtxt( sound_data, unpack=True)
    wdir[wdir == 360] = 0. # Some wind directions are 360. Like in /glade/work/ahijevyc/GFS/Joaquin/g132325165.frd
    return p, h, T, Td, wdir, utils.MS2KTS(wspd), float(slat), float(slon)

model_str = {"hwt2017":"MPAS-US 15-3km","us":"MPAS-US 60-15km","wp":"MPAS-WP 60-15km","al":"MPAS-AL 60-15km",
		"ep":"MPAS-EP 60-15km","uni":"MPAS 15km",
		"mpas":"MPAS 15km","mpas_ep":"MPAS-EP 60-15km","spring_exp":"MPAS","GFS":"GFS",
		"mpas15_3":"MPAS 15-3km","mpas50_3":"MPAS 50-3km","hwt":"MPAS HWT"}

no_ignore_station = ["S07W112","N15E121","N18E121","N20W155","N22W159","N24E124","N35E125","N35E127","N36E129","N37E127","N38E125","N40E140","N40W105"]

def get_title(sfile):
    title = sfile
    fname = os.path.basename(sfile)
    if '.snd' in fname:
        words = os.path.realpath(sfile).split('/')
        # Find 1st word in the absolute path that is yyyymmddhh format. Assume it is the initialization time.
        for i,word in enumerate(words):
            try:
                dt.datetime.strptime(word, '%Y%m%d%H')
            except ValueError:
                continue
            break
        init_time = words[i]
        model = words[i-1]
        parts = fname.split('.')
        station = parts[0]
        valid_time = parts[1]
        fhr = dt.datetime.strptime(valid_time, "%Y%m%d%H%M") - dt.datetime.strptime(init_time,"%Y%m%d%H")
        fhr = fhr.total_seconds()/3600.
	if model not in model_str:
		print model, "is not in model_str. Can't get title"
		sys.exit(2)
        title = model_str[model]+'  %dh fcst' % fhr + '  Station: '+station+'\nInit: '+init_time+'  Valid: '+valid_time+' UTC'
    return title, station, init_time, valid_time, fhr
    
# Create a new figure. The dimensions here give a good aspect ratio
# Static parts defined here outside the loop for speed.
# Also define some line and text objects here outside loop to save time.
# Alter their positions within the loop using object methods like set_data(), set_text, set_position(), etc.

fig, ax = plt.subplots(subplot_kw={"projection":"skewx"},figsize=(7.25,5.4))
plt.tight_layout(rect=(0.04,0.02,0.79,.96))
ax.grid(True, color='black', linestyle='solid', alpha=0.2)
skewt.draw_background(ax)

# Define line2D objects for use later.
# Plot the data using normal plotting functions, in this case using
# log scaling in Y, as dictated by the typical meteorological plot
tmpc_line, = ax.semilogy([], [], 'r', lw=2) # Plot the temperature profile
# Write temperature in F at bottom of T profile
temperatureF = ax.text([],[],'', verticalalignment='top', horizontalalignment='center', size=7, color=tmpc_line.get_color())
vtmp_line, = ax.semilogy([], [], 'r', lw=0.8) # Plot the virt. temperature profile
wetbulb_line, = ax.semilogy([],[], 'c-') # Plot the wetbulb profile
dwpc_line, = ax.semilogy([],[], 'g', lw=2) # plot the dewpoint profile
dewpointF = ax.text([],[],'', verticalalignment='top', horizontalalignment='center', size=7, color=dwpc_line.get_color())
ttrace_line, = ax.semilogy([],[], color='brown', ls='dashed', lw=1.5) # plot the parcel trace 

# example of a slanted line at constant temperature 
l = ax.axvline(-20, color='b', linestyle='dashed', alpha=0.5, linewidth=1)
l = ax.axvline(0, color='b', linestyle='dashed', alpha=0.5, linewidth=1)

# Plot the effective inflow layer using purple horizontal lines
inflow_bot = ax.axhline(color='purple',xmin=0.38, xmax=0.45)
inflow_top = ax.axhline(color='purple',xmin=0.38, xmax=0.45)
inflow_SRH = ax.text(0.415,1000,'', verticalalignment='bottom', horizontalalignment='center', size=6, transform=inflow_bot.get_transform(), color=inflow_top.get_color())

# Disables the log-formatting that comes with semilogy
ax.yaxis.set_major_formatter(plt.ScalarFormatter())
ax.set_yticks(np.linspace(100,1000,10))
ax.set_ylim(1050,100)
ax.xaxis.set_major_locator(plt.MultipleLocator(10))
ax.set_xlim(-50,45)

# 'knots' label under wind barb stack
kts = plt.text(1.0, 1035, 'knots', clip_on=False, transform=ax.get_yaxis_transform(),ha='center',va='top',size=7)

# Indices go to the right of plot.
indices_text = plt.text(1.08, 1.0, '', verticalalignment='top', size=5.6, transform=plt.gca().transAxes)

# Draw the hodograph on the Skew-T.
hodo_ax = skewt.draw_hodo()

# Plot Bunker's Storm motion left mover as a blue dot
bunkerL, = hodo_ax.plot([], [], color='b', alpha=0.7, linestyle="None", marker="o", markersize=5, mew=0, label="left mover")
# Plot Bunker's Storm motion right mover as a red dot
# The comma after bunkerR de-lists it.
bunkerR, = hodo_ax.plot([], [], color='r', alpha=0.7, linestyle="None", marker="o", markersize=5, mew=0, label="right mover")
# Explanation for red and blue dots. Put only 1 point in the legend entry.
bunkerleg = hodo_ax.legend(handles=[bunkerL,bunkerR], fontsize=5, frameon=False, numpoints=1)


for sfile in sfiles:
    print "reading", sfile
    title, station, init_time, valid_time, fhr = get_title(sfile)
    if fhr % args.interval != 0:
        print "fhr not multiple of", args.interval, "skipping", sfile
        continue
    if len(station) > 3 and station not in no_ignore_station:
        print "skipping", sfile
        continue
    ax.set_title(title, horizontalalignment="left", x=0, fontsize=12) 
    # Avoid './' on the beginning for rsync command to not produce "skipping directory ." message.
    ofile = init_time+'/'+project+'.skewt.'+station+'.hr'+'%03d'%fhr+'.png'
    if not force_new and os.path.isfile(ofile): continue
    data = open(sfile).read()
    pres, hght, tmpc, dwpc, wdir, wspd, latitude, longitude = parseGEMPAK(data)

    if wdir.size == 0:
        print "no good data lines. empty profile"
        continue

    prof = profile.create_profile(profile='default', pres=pres, hght=hght, tmpc=tmpc, 
                                    dwpc=dwpc, wspd=wspd, wdir=wdir, latitude=latitude, longitude=longitude, missing=-999., strictQC=True)

    sfcpcl = params.parcelx( prof, flag=1 ) # Surface Parcel
    #fcstpcl = params.parcelx( prof, flag=2 ) # Forecast Parcel
    mupcl = params.parcelx( prof, flag=3 ) # Most-Unstable Parcel
    mlpcl = params.parcelx( prof, flag=4 ) # 100 mb Mean Layer Parcel


    #### Adding a Parcel Trace and plotting Moist and Dry Adiabats:

    # Set the parcel trace to be plotted as the Most-Unstable parcel.
    pcl = mupcl

    tmpc_line.set_data(prof.tmpc, prof.pres) # Update the temperature profile
    # Update temperature in F at bottom of T profile
    temperatureF.set_text( utils.INT2STR(thermo.ctof(prof.tmpc[0])) ) 
    temperatureF.set_position((prof.tmpc[0], prof.pres[0]+10))#note double parentheses-needs to be 1 argument, not 2
    vtmp_line.set_data(prof.vtmp, prof.pres) # Update the virt. temperature profile
    wetbulb_line.set_data(prof.wetbulb, prof.pres) # Plot the wetbulb profile
    dwpc_line.set_data(prof.dwpc, prof.pres) # plot the dewpoint profile
    # Update dewpoint in F at bottom of dewpoint profile
    dewpointF.set_text( utils.INT2STR(thermo.ctof(prof.dwpc[0])) ) 
    dewpointF.set_position((prof.dwpc[0], prof.pres[0]+10))
    ttrace_line.set_data(pcl.ttrace, pcl.ptrace) # plot the parcel trace 
    # Move 'knots' label below winds
    kts.set_position((1.0, prof.pres[0]+10))

    srwind = params.bunkers_storm_motion(prof)
    eff_inflow = params.effective_inflow_layer(prof)
    # Update the effective inflow layer using horizontal lines
    inflow_bot.set_ydata(eff_inflow[0])
    inflow_top.set_ydata(eff_inflow[1])
    # Update the effective inflow layer SRH text
    if eff_inflow[0]:
        ebot_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[0]))
        etop_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[1]))
        effective_srh = winds.helicity(prof, ebot_hght, etop_hght, stu = srwind[0], stv = srwind[1])
        # Set position of label
        # x position is mean of horizontal line bounds
        # For some reason this makes a big white space on the left side and for all subsequent plots.
        inflow_SRH.set_position((np.mean(inflow_top.get_xdata()), eff_inflow[1]))
        inflow_SRH.set_text('%.0f' % effective_srh[0] + ' ' + '$\mathregular{m^{2}s^{-2}}$')
    else:
        inflow_SRH.set_text('')

    # draw indices text string
    indices_text.set_text(skewt.indices(prof))

    # globe with dot
    mapax = skewt.add_globe(longitude, latitude)

    # Update the hodograph on the Skew-T.
    hodo, AGL = skewt.add_hodo(hodo_ax, prof)

    # show Bunker left/right movers if 0-6km shear magnitude >= 20kts
    p6km = interp.pres(prof, interp.to_msl(prof, 6000.))
    sfc_6km_shear = winds.wind_shear(prof, pbot=prof.pres[prof.sfc], ptop=p6km)
    if utils.comp2vec(sfc_6km_shear[0], sfc_6km_shear[1])[1] >= 20.:
        bunkerR.set_visible(True)
        bunkerL.set_visible(True)
        bunkerleg.set_visible(True)
        bunkerR.set_data(srwind[0], srwind[1]) # Update Bunker's Storm motion right mover
        bunkerL.set_data(srwind[2], srwind[3]) # Update Bunker's Storm motion left mover
    else:
        bunkerR.set_visible(False)
        bunkerL.set_visible(False)
        bunkerleg.set_visible(False)

    # Recreate stack of wind barbs
    s = []
    bot=2000.
    # Space out wind barbs evenly on log axis.
    for ind, i in enumerate(prof.pres):
        if i < 100: break
        if np.log(bot/i) > 0.04:
            s.append(ind)
            bot = i
    # x coordinate in (0-1); y coordinate in pressure log(p)
    b = plt.barbs(1.0*np.ones(len(prof.pres[s])), prof.pres[s], prof.u[s], prof.v[s],
          length=6, lw=0.4, clip_on=False, transform=ax.get_yaxis_transform())

    res = mysavfig(ofile,dpi=125)
    # Remove stack of wind barbs (or it will be on the next plot)
    b.remove()
    mapax.clear()
    hodo.remove() # remove hodograph line
    for i in AGL: # remove each hodograph AGL text label (there has got to be a better way)
        i.remove()

    # Copy to web server
    if '.snd' in sfile: 
        cmd = "rsync -R "+ofile+" ahijevyc@nova.mmm.ucar.edu:/web/htdocs/projects/mpas/plots"
        print(cmd)
        call(cmd.split()) 

plt.close('all')

