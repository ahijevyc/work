#!/bin/env python

# coding: utf-8

## Basic Coding With SHARPpy

# Written by: Greg Blumberg (OU/CIMMS)

##### This IPython Notebook tutorial is meant to teach the user how to directly interact with the SHARPpy libraries using the Python interpreter.  This tutorial will cover reading in files into the the Profile object, plotting the data using Matplotlib, and computing various indices from the data.  It is also a reference to the different functions and variables SHARPpy has available to the user.

# In order to work with SHARPpy, you need to perform 3 steps before you can begin running routines such as CAPE/CIN on the data.

#### Step 1: Read in the data to work with.

# 1.) The Pilger, NE tornado proximity sounding from 19 UTC within the tutorial/ directory is an example of the SPC sounding file format that can be read in by the GUI.  Here we'll read it in manually.

# In[1]:

import glob,sys,os,getopt

force_new = False
nplots = -1
usage = 'SHARPpy_skewts.py [-f] [yyyymmddhh conv]'
try:
	opts, args = getopt.getopt(sys.argv[1:],"hfn:")
except getopt.GetoptError:
	print usage
	sys.exit(2)
for opt, arg in opts:
	if opt == '-h':
		print usage
		sys.exit()
	elif opt == '-f':
		force_new = True
	elif opt == '-n':
		nplots = int(arg)
		
# redefine the argument list to be the stripped-down version returned by getopt().
sys.argv[1:] = args			

sfile = '/glade/p/work/ahijevyc/mpex/May19Upsondes/NSSL_20130519190000'
sfile = '/glade/scratch/mpasrt/conv/2016051700/SHV.201605180000.snd'
#sfile = '/glade/p/work/ahijevyc/GFS/Joaquin/g132335064.frd'

sfiles = glob.glob('/glade/p/work/ahijevyc/GFS/Joaquin/*.frd')
sfiles = glob.glob('/glade/scratch/mpasrt/conv/2016051800/OUN*.snd')
sfiles = sfiles[0:nplots]

if len(sys.argv)>1:
	init_time = sys.argv[1]
	rundir = sys.argv[2]
	os.chdir("/glade/scratch/mpasrt/%s/%s/plots/"%(rundir,init_time))
	sfiles = []
	stations = ["ABQ", "ABR", "ALY", "AMA", "APX", "BIS", "BMX", "BNA", "BRO", "BUF", "CAR", "CHH", "CHS", "CRP", "DDC", "DNR", "DRT", "DTX", "EPZ", "EYW", "FFC", "FGZ", "FWD", "GGW", "GJT", "GRB", "GSO", "GYX", "IAD", "ILN", "ILX", "INL", "JAN", "JAX", "LBF", "LCH", "LMN", "LZK", "MAF", "MFL", "MHX", "MPX", "OAX", "OKX", "OUN", "PIT", "QAG", "REE", "RIW", "RNK", "S07W112", "SGF", "SHV", "SIL", "SLC", "TBW", "TFX", "TLH", "TOP", "TUS", "UNR", "VPS", "WAL", "XMR"]
	for station in stations:
		sfiles.extend(glob.glob("../"+station+".*.snd"))


sys.path.append('/glade/u/home/ahijevyc/lib/python2.7/site-packages/SHARPpy-1.3.0-py2.7.egg')
import sharppy
import sharppy.sharptab.profile as profile
import sharppy.sharptab.interp as interp
import sharppy.sharptab.winds as winds
import sharppy.sharptab.utils as utils
import sharppy.sharptab.params as params
import sharppy.sharptab.thermo as thermo
import numpy as np
from StringIO import StringIO

sys.path.append('/glade/p/work/ahijevyc/skewt')
from skewx_projection import SkewXAxes
def parseFRD(sfile):
    ## read in the file
    data = np.array([l.strip() for l in sfile.split('\n')])

    ## necessary index points
    start_idx = 21
    finish_idx = len(data)
    
    ## put it all together for StringIO
    full_data = '\n'.join(data[start_idx : finish_idx][:])
    sound_data = StringIO( full_data )

    ## read the data into arrays
    data = np.genfromtxt( sound_data, usecols=(2,5,3,4,6,7))
    clean_data = []
    for i in data:
	if i[0] != -999 and i[1] != -999 and i[2] != -999 and i[3] != -999 and i[4] != -999 and i[5] != -999:
	    clean_data.append(i)
    p = np.array([i[0] for i in clean_data])
    h = np.array([i[1] for i in clean_data])
    T = np.array([i[2] for i in clean_data])
    RH = np.array([i[3] for i in clean_data])
    wdir = np.array([i[4] for i in clean_data])
    wspd = np.array([i[5] for i in clean_data])
    wspd = utils.MS2KTS(wspd)
    wdir[wdir == 360] = 0. # Some wind directions are 360. Like in /glade/p/work/ahijevyc/GFS/Joaquin/g132325165.frd

    Td = dewpoint_approximation(T,RH)
    max_points = 250
    s = -1 * p.size/max_points
    if s == 0: s = 1
    print "stride=",s
    return p[::s], h[::s], T[::s], Td[::s], wdir[::s], wspd[::s]

def parseGEMPAK(sfile):
    ## read in the file
    data = np.array([l.strip() for l in sfile.split('\n')])
    stidline = data[2]
    slatline = data[3]
    ## Grab 3rd, 6th, and 9th words
    stid, stnm, time = data[2].split()[2:9:3]
    slat, slon, selv = data[3].split()[2:9:3]
    ## necessary index points
    start_idx = 6
    finish_idx = len(data)
    ## put it all together for StringIO
    full_data = '\n'.join(data[start_idx : finish_idx][:])
    sound_data = StringIO( full_data )
    ## read the data into arrays
    p, h, T, Td, wdir, wspd = np.genfromtxt( sound_data, unpack=True)
    wdir[wdir == 360] = 0. # Some wind directions are 360. Like in /glade/p/work/ahijevyc/GFS/Joaquin/g132325165.frd
    return p, h, T, Td, wdir, utils.MS2KTS(wspd), slat, slon

def thetas(theta, presvals):
    return ((theta + thermo.ZEROCNK) / (np.power((1000. / presvals),thermo.ROCP))) - thermo.ZEROCNK

# approximation valid for
# 0 degC < T < 60 degC
# 1% < RH < 100%
# 0 degC < Td < 50 degC 
	 
	  
def dewpoint_approximation(T,RH):
    # constants
    a = 17.271
    b = 237.7 # degC
	 
    Td = (b * gamma(T,RH)) / (a - gamma(T,RH))
 
    return Td
 
 
def gamma(T,RH):
    # constants
    a = 17.271
    b = 237.7 # degC
    
    g = (a * T / (b + T)) + np.log(RH/100.0)
 
    return g

# Call this before pyplot
# avoids X11 window display error as mpasrt
# says we won't be using X11 (i.e. use a non-interactive backend instead)
import matplotlib as mpl
mpl.use('Agg')

import matplotlib.pyplot as plt
import datetime as dt
from subprocess import call # to use "mogrify"

def mysavfig(ofile, dpi=125):
    plt.savefig(ofile,dpi=dpi)
    cmd = "mogrify +matte -type Palette -colors 255 " + ofile # prevents flickering when displaying on yellowstone.
    return call(cmd.split()) 

def get_title(sfile):
    title = sfile
    if '.snd' in sfile:
	words = os.path.realpath(sfile).split('/')
	init_time = words[-2]
	fname = os.path.basename(sfile)
	parts = fname.split('.')
	station = parts[0]
	valid_time = parts[1]
	valid_time = valid_time[:-2] # Strip '00' minutes from end
	fhr = dt.datetime.strptime(valid_time, "%Y%m%d%H") - dt.datetime.strptime(init_time,"%Y%m%d%H")
	fhr = fhr.total_seconds()/3600.
	title = 'Station: '+station+'  Init: '+init_time+' UTC Valid: '+valid_time
    return title, station, init_time, valid_time, fhr
	


# Create a new figure. The dimensions here give a good aspect ratio
# Static parts defined here outside the loop for speed.
# Also define some line and text objects here outside loop to save time.
# Alter their positions within the loop using object methods like set_data(), set_text, set_position(), etc.
fig = plt.figure(figsize=(7.25, 5.4))
ax = fig.add_subplot(111, projection='skewx')
plt.tight_layout(rect=(0.04,0.02,0.79,1))
ax.grid(True, color='orange')
plt.ylabel('Pressure (hPa)')
plt.xlabel('Temperature (C)')

pmax = 1000
pmin = 10
dp = -10
presvals = np.arange(int(pmax), int(pmin)+dp, dp)

# plot the moist-adiabats
for t in np.arange(-10,45,5):
    tw = []
    for p in presvals:
	tw.append(thermo.wetlift(1000., t, p))
    ax.semilogy(tw, presvals, 'k-', alpha=.2)

# plot the dry adiabats
for t in np.arange(-50,110,10):
    ax.semilogy(thetas(t, presvals), presvals, 'r-', alpha=.2)

# Define line2D objects for use later.
# Plot the data using normal plotting functions, in this case using
# log scaling in Y, as dicatated by the typical meteorological plot
tmpc_line, = ax.semilogy([], [], 'r', lw=2) # Plot the temperature profile
# Write temperature in F at bottom of T profile
temperatureF = ax.text([],[],'', verticalalignment='top', horizontalalignment='center', size=7, color=tmpc_line.get_color())
vtmp_line, = ax.semilogy([], [], 'r', lw=0.8) # Plot the virt. temperature profile
wetbulb_line, = ax.semilogy([],[], 'c-') # Plot the wetbulb profile
dwpc_line, = ax.semilogy([],[], 'g', lw=2) # plot the dewpoint profile
dewpointF = ax.text([],[],'', verticalalignment='top', horizontalalignment='center', size=7, color=dwpc_line.get_color())
ttrace_line, = ax.semilogy([],[], color='brown', ls='dashed', lw=1.5) # plot the parcel trace 
# An example of a slanted line at constant X
l = ax.axvline(0, color='b', linestyle='--')

# Plot the effective inflow layer using blue horizontal lines
inflow_bot = ax.axhline(color='purple')
inflow_top = ax.axhline(color='purple')

# Disables the log-formatting that comes with semilogy
ax.yaxis.set_major_formatter(plt.ScalarFormatter())
ax.set_yticks(np.linspace(100,1000,10))
ax.set_ylim(1050,100)
ax.xaxis.set_major_locator(plt.MultipleLocator(10))
ax.set_xlim(-50,45)

# 'kts' label under wind barb stack
kts = plt.text(1.0, 1035, 'kts', clip_on=False, transform=ax.get_yaxis_transform(),ha='center',va='top',size=7)

# Indices go to the right of plot.
indices_text = plt.text(1.06, 1, '', verticalalignment='top', size=8.9, transform=plt.gca().transAxes)

# Draw the hodograph on the Skew-T.
bbox_props = dict(boxstyle="square", color="w",alpha=0.6)
ax2 = plt.axes([.5,.67,.2,.26])
hodo, = ax2.plot([],[], 'k-', lw=1.2, zorder=2)
ax2.get_xaxis().set_visible(False)
ax2.get_yaxis().set_visible(False)
az = np.radians(-35)
for i in range(10,100,10):
    # Draw the range rings around the hodograph.
    lw = .5 if i % 20 == 0 else 0.25
    circle = plt.Circle((0,0),i,color='k',alpha=.5, fill=False, lw=lw)
    ax2.add_artist(circle)
    if i % 20 == 0 and i < 100:
	plt.text(i*np.cos(az),i*np.sin(az),str(i)+"kts",rotation=np.degrees(az),size=5,alpha=.5,ha='center',
		zorder=1, bbox=bbox_props)

ax2.set_xlim(-40,80)
ax2.set_ylim(-60,60)
ax2.axhline(y=0, color='k')
ax2.axvline(x=0, color='k')

bbox_props = dict(boxstyle="square", fc="w", ec="0.5", alpha=0.8)
ax2.text(-35,-55,'km AGL',size=5,bbox=bbox_props)
AGLs = [] # Create list of AGL labels
for i in [1,3,6,10]:
    AGLs.append(ax2.text(0,0,str(i),ha='center',va='center',size=5,bbox=bbox_props))

bunkerR, = ax2.plot([], [], 'ro',alpha=0.8) # Plot Bunker's Storm motion right mover as a red dot
bunkerL, = ax2.plot([], [], 'bo',alpha=0.8) # Plot Bunker's Storm motion left mover as a blue dot

for sfile in sfiles:
	print "reading ", sfile
	title, station, init_time, valid_time, fhr = get_title(sfile)
	fig.suptitle(title) # title over everything (not just skewT box)
	ofile = os.path.dirname(sfile)+'/'+os.path.basename(sfile)+'.png'
	ofile = './'+os.path.basename(sfile)+'.png'
	if len(sys.argv)>1 and '.snd' in sfile: 
		ofile = './wrf/spring_exp/'+init_time+'/spring_exp.'+station+'_'+init_time+ '_f'+'%03d'%fhr+'.png'
	if not force_new and os.path.isfile(ofile): continue
	data = open(sfile).read()
	 
	if '.frd' in sfile:
	    pres, hght, tmpc, dwpc, wdir, wspd = parseFRD(data)
	else:
	    pres, hght, tmpc, dwpc, wdir, wspd, latitude, longitude = parseGEMPAK(data)

	if wdir.size == 0:
	    print "no good data lines. empty profile"
	    continue

	prof = profile.create_profile(profile='default', pres=pres, hght=hght, tmpc=tmpc, 
                                    dwpc=dwpc, wspd=wspd, wdir=wdir, latitude=latitude, longitude=longitude, missing=-999., strictQC=True)

	### Working with the data:

	# Once you have a Profile object, you can begin running analysis routines and plotting the data.  The following sections show different examples of how to do this.
	# SHARPpy Profile objects keep track of the height grid the profile lies on.  Within the profile object, the height grid is assumed to be in meters above mean sea level.
	# 

	#### Lifting Parcels:

	# In SHARPpy, parcels are lifted via the params.parcelx() routine.  The parcelx() routine takes in the arguments of a Profile object and a flag to indicate what type of parcel you would like to be lifted.  Additional arguments can allow for custom/user defined parcels to be passed to the parcelx() routine, however most users will likely be using only the Most-Unstable, Surface, 100 mb Mean Layer, and Forecast parcels.
	# 
	# The parcelx() routine by default utilizes the virtual temperature correction to compute variables such as CAPE and CIN.  If the dewpoint profile contains missing data, parcelx() will disregard using the virtual temperature correction.

	# In[180]:

	sfcpcl = params.parcelx( prof, flag=1 ) # Surface Parcel
	#fcstpcl = params.parcelx( prof, flag=2 ) # Forecast Parcel
	mupcl = params.parcelx( prof, flag=3 ) # Most-Unstable Parcel
	mlpcl = params.parcelx( prof, flag=4 ) # 100 mb Mean Layer Parcel


	# Once your parcel attributes are computed by params.parcelx(), you can extract information about the parcel such as CAPE, CIN, LFC height, LCL height, EL height, etc.

	# In[181]:

	#print "Most-Unstable CAPE:", mupcl.bplus # J/kg
	#print "Most-Unstable CIN:", mupcl.bminus # J/kg
	#print "Most-Unstable LCL:", mupcl.lclpres
	#print "Most-Unstable LFC:", mupcl.lfcpres
	#print "Most-Unstable EL:", mupcl.elhght # meters AGL
	#print "Most-Unstable LI:", mupcl.li5 # C

	#### Other Parcel Object Attributes:

	# Here is a list of the attributes and their units contained in each parcel object (pcl):

	#     pcl.pres - Parcel beginning pressure (mb)
	#     pcl.tmpc - Parcel beginning temperature (C)
	#     pcl.dwpc - Parcel beginning dewpoint (C)
	#     pcl.ptrace - Parcel trace pressure (mb)
	#     pcl.ttrace - Parcel trace temperature (C)
	#     pcl.blayer - Pressure of the bottom of the layer the parcel is lifted (mb)
	#     pcl.tlayer - Pressure of the top of the layer the parcel is lifted (mb)
	#     pcl.lclpres - Parcel LCL (lifted condensation level) pressure (mb)
	#     pcl.lclhght - Parcel LCL height (m AGL)
	#     pcl.lfcpres - Parcel LFC (level of free convection) pressure (mb)
	#     pcl.lfchght - Parcel LFC height (m AGL)
	#     pcl.elpres - Parcel EL (equilibrium level) pressure (mb)
	#     pcl.elhght - Parcel EL height (m AGL)
	#     pcl.mplpres - Maximum Parcel Level (mb)
	#     pcl.mplhght - Maximum Parcel Level (m AGL)
	#     pcl.bplus - Parcel CAPE (J/kg)
	#     pcl.bminus - Parcel CIN (J/kg)
	#     pcl.bfzl - Parcel CAPE up to freezing level (J/kg)
	#     pcl.b3km - Parcel CAPE up to 3 km (J/kg)
	#     pcl.b6km - Parcel CAPE up to 6 km (J/kg)
	#     pcl.p0c - Pressure value at 0 C  (mb)
	#     pcl.pm10c - Pressure value at -10 C (mb)
	#     pcl.pm20c - Pressure value at -20 C (mb)
	#     pcl.pm30c - Pressure value at -30 C (mb)
	#     pcl.hght0c - Height value at 0 C (m AGL)
	#     pcl.hghtm10c - Height value at -10 C (m AGL)
	#     pcl.hghtm20c - Height value at -20 C (m AGL)
	#     pcl.hghtm30c - Height value at -30 C (m AGL)
	#     pcl.wm10c - Wet bulb velocity at -10 C 
	#     pcl.wm20c - Wet bulb velocity at -20 C
	#     pcl.wm30c - Wet bulb at -30 C
	#     pcl.li5 = - Lifted Index at 500 mb (C)
	#     pcl.li3 = - Lifted Index at 300 mb (C)
	#     pcl.brnshear - Bulk Richardson Number Shear
	#     pcl.brnu - Bulk Richardson Number U (kts)
	#     pcl.brnv - Bulk Richardson Number V (kts)
	#     pcl.brn - Bulk Richardson Number (unitless)
	#     pcl.limax - Maximum Lifted Index (C)
	#     pcl.limaxpres - Pressure at Maximum Lifted Index (mb)
	#     pcl.cap - Cap Strength (C)
	#     pcl.cappres - Cap strength pressure (mb)
	#     pcl.bmin - Buoyancy minimum in profile (C)
	#     pcl.bminpres - Buoyancy minimum pressure (mb)

	#### Adding a Parcel Trace and plotting Moist and Dry Adiabats:

	# In[182]:

	pcl = mupcl

	#### Calculating Kinematic Variables:

	# SHARPpy also allows the user to compute kinematic variables such as shear, mean-winds, and storm relative helicity.  SHARPpy will also compute storm motion vectors based off of the work by Stephen Corfidi and Matthew Bunkers.  Below is some example code to compute the following:
	# 
	# 1.) 0-3 km Pressure-Weighted Mean Wind
	# 
	# 2.) 0-6 km Shear (kts)
	# 
	# 3.) Bunker's Storm Motion (right-mover) (Bunkers et al. 2014 version)
	# 
	# 4.) Bunker's Storm Motion (left-mover) (Bunkers et al. 2014 version)
	# 
	# 5.) 0-3 Storm Relative Helicity
	# 

	# In[183]:

	sfc = prof.pres[prof.sfc]
	p3km = interp.pres(prof, interp.to_msl(prof, 3000.))
	p6km = interp.pres(prof, interp.to_msl(prof, 6000.))
	p1km = interp.pres(prof, interp.to_msl(prof, 1000.))
	mean_3km = winds.mean_wind(prof, pbot=sfc, ptop=p3km)
	sfc_6km_shear = winds.wind_shear(prof, pbot=sfc, ptop=p6km)
	sfc_3km_shear = winds.wind_shear(prof, pbot=sfc, ptop=p3km)
	sfc_1km_shear = winds.wind_shear(prof, pbot=sfc, ptop=p1km)
	#print "0-3 km Pressure-Weighted Mean Wind (kt):", utils.comp2vec(mean_3km[0], mean_3km[1])[1]
	#print "0-6 km Shear (kt):", utils.comp2vec(sfc_6km_shear[0], sfc_6km_shear[1])[1]
	srwind = params.bunkers_storm_motion(prof)
	#print "Bunker's Storm Motion (right-mover) [deg,kts]:", utils.comp2vec(srwind[0], srwind[1])
	#print "Bunker's Storm Motion (left-mover) [deg,kts]:", utils.comp2vec(srwind[2], srwind[3])
	srh3km = winds.helicity(prof, 0, 3000., stu = srwind[0], stv = srwind[1])
	srh1km = winds.helicity(prof, 0, 1000., stu = srwind[0], stv = srwind[1])
	#print "0-3 km Storm Relative Helicity [m2/s2]:",srh3km[0]


	#### Calculating variables based off of the effective inflow layer:

	# The effective inflow layer concept is used to obtain the layer of buoyant parcels that feed a storm's inflow.  Here are a few examples of how to compute variables that require the effective inflow layer in order to calculate them:

	# In[184]:

	stp_fixed = params.stp_fixed(sfcpcl.bplus, sfcpcl.lclhght, srh1km[0], utils.comp2vec(sfc_6km_shear[0], sfc_6km_shear[1])[1])
	ship = params.ship(prof)
	eff_inflow = params.effective_inflow_layer(prof)
	ebot_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[0]))
	etop_hght = interp.to_agl(prof, interp.hght(prof, eff_inflow[1]))
	print "Effective Inflow Layer Bottom Height (m AGL):", ebot_hght
	print "Effective Inflow Layer Top Height (m AGL):", etop_hght
	effective_srh = winds.helicity(prof, ebot_hght, etop_hght, stu = srwind[0], stv = srwind[1])
	#print "Effective Inflow Layer SRH (m2/s2):", effective_srh[0]
	ebwd = winds.wind_shear(prof, pbot=eff_inflow[0], ptop=eff_inflow[1])
	ebwspd = utils.mag( ebwd[0], ebwd[1] )
	#print "Effective Bulk Wind Difference:", ebwspd
	scp = params.scp(mupcl.bplus, effective_srh[0], ebwspd)
	stp_cin = params.stp_cin(mlpcl.bplus, effective_srh[0], ebwspd, mlpcl.lclhght, mlpcl.bminus)
	#print "Supercell Composite Parameter:", scp
	#print "Significant Tornado Parameter (w/CIN):", stp_cin
	#print "Significant Tornado Parameter (fixed):", stp_fixed


	#### Putting it all together into one plot:

	# If you get an error about not converting masked constant to python int 
	# use the round() function instead of int() - Ahijevych May 11 2016
	# 2nd element of list is the # of decimal places
	indices = {'SBCAPE': [sfcpcl.bplus, 0, 'J $\mathregular{kg^{-1}}$'],
           'SBCIN': [sfcpcl.bminus, 0, 'J $\mathregular{kg^{-1}}$'],
           'SBLCL': [sfcpcl.lclhght, 0, 'm AGL'],
           'SBLFC': [sfcpcl.lfchght, 0, 'm AGL'],
           'SBEL': [sfcpcl.elhght, 0, 'm AGL'],
           'SBLI': [sfcpcl.li5, 0, 'C'],
           'MLCAPE': [mlpcl.bplus, 0, 'J $\mathregular{kg^{-1}}$'],
           'MLCIN': [mlpcl.bminus, 0, 'J $\mathregular{kg^{-1}}$'],
           'MLLCL': [mlpcl.lclhght, 0, 'm AGL'],
           'MLLFC': [mlpcl.lfchght, 0, 'm AGL'],
           'MLEL': [mlpcl.elhght, 0, 'm AGL'],
           'MLLI': [mlpcl.li5, 0, 'C'],
           'MUCAPE': [mupcl.bplus, 0, 'J $\mathregular{kg^{-1}}$'],
           'MUCIN': [mupcl.bminus, 0, 'J $\mathregular{kg^{-1}}$'],
           'MULCL': [mupcl.lclhght, 0, 'm AGL'],
           'MULFC': [mupcl.lfchght, 0, 'm AGL'],
           'MUEL': [mupcl.elhght, 0, 'm AGL'],
           'MULI': [mupcl.li5, 0, 'C'],
           '0-1 km SRH': [srh1km[0], 0, '$\mathregular{m^{2}s^{-2}}$'],
           '0-1 km Shear': [utils.comp2vec(sfc_1km_shear[0], sfc_1km_shear[1])[1], 0, 'kts'],
           '0-3 km SRH': [srh3km[0], 0, '$\mathregular{m^{2}s^{-2}}$'],
           'Eff. SRH': [effective_srh[0], 0, '$\mathregular{m^{2}s^{-2}}$'],
           'EBWD': [ebwspd, 0, 'kts'],
           'PWV': [params.precip_water(prof), 2, 'inch'],
           'K-index': [params.k_index(prof), 0, ''],
           'STP(fix)': [stp_fixed, 1, ''],
           'SHIP': [ship, 1, ''],
           'SCP': [scp, 1, ''],
           'STP(cin)': [stp_cin, 1, '']}

	# Set the parcel trace to be plotted as the Most-Unstable parcel.
	pcl = mupcl

	tmpc_line.set_data(prof.tmpc, prof.pres) # Update the temperature profile
	# Update temperature in F at bottom of T profile
	temperatureF.set_text( int(thermo.ctof(prof.tmpc[0]).round()) ) 
	temperatureF.set_position((prof.tmpc[0], prof.pres[0]+10))#note double parentheses-needs to be 1 argument, not 2
	vtmp_line.set_data(prof.vtmp, prof.pres) # Update the virt. temperature profile
	wetbulb_line.set_data(prof.wetbulb, prof.pres) # Plot the wetbulb profile
	dwpc_line.set_data(prof.dwpc, prof.pres) # plot the dewpoint profile
	# Update dewpoint in F at bottom of dewpoint profile
	dewpointF.set_text( int(thermo.ctof(prof.dwpc[0]).round()) ) 
	dewpointF.set_position((prof.dwpc[0], prof.pres[0]+10))
	ttrace_line.set_data(pcl.ttrace, pcl.ptrace) # plot the parcel trace 
	# Move 'kts' label below winds
	kts.set_position((1.0, prof.pres[0]+10))

	# Update the effective inflow layer using horizontal lines
	inflow_bot.set_ydata(eff_inflow[0])
	inflow_top.set_ydata(eff_inflow[1])
	# Update the indices within the indices dictionary on the side of the plot.
	string = ''
	for key in np.sort(indices.keys()):
	    format = '%.'+str(indices[key][1])+'f'
	    string = string + key + ': ' + (format % indices[key][0]) + ' ' + indices[key][2] + '\n'
	print string
	indices_text.set_text(string)

	# Update the hodograph on the Skew-T.
	below_12km = np.where(interp.to_agl(prof, prof.hght) < 12000)[0]
	u_prof = prof.u[below_12km]
	v_prof = prof.v[below_12km]
	hodo.set_data(u_prof[~u_prof.mask], v_prof[~u_prof.mask])
	for a in AGLs:
	    i = 1000*int(a.get_text())
	    if i > np.max(interp.to_agl(prof, prof.hght)): 
		a.visible = False
	    else:
	    	ind = np.min(np.where(interp.to_agl(prof,prof.hght)>i))
	    	a.set_position((prof.u[ind],prof.v[ind]))
		a.visible = True
	bunkerR.set_data(srwind[0], srwind[1]) # Update Bunker's Storm motion right mover
	bunkerL.set_data(srwind[2], srwind[3]) # Update Bunker's Storm motion left mover

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
		  length=6, lw=0.5, clip_on=False, transform=ax.get_yaxis_transform())


	res = mysavfig(ofile)
	print "created "+ofile
	# Remove stack of wind barbs (or it will be on the next plot)
	b.remove()

	# Copy to web server
	if len(sys.argv)>1 and '.snd' in sfile: 
		cmd = "rsync -Rv "+ofile+" ahijevyc@nebula.mmm.ucar.edu:/web/htdocs/prod/rt/."
		call(cmd.split()) 

plt.close('all')

