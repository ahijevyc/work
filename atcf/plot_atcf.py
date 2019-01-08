# In order for Basemap to work,
# Had to add ~/lib/python2.7/site-packages to PYTHONPATH
# i.e. setenv PYTHONPATH /Users/ahijevyc/Library/Python/2.7/lib/python/site-packages:/Users/ahijevyc/lib/python2.7/site-packages
from mpl_toolkits.basemap import Basemap
from matplotlib import colors
from netCDF4 import Dataset
from mysavfig import mysavfig
from mpas import origmesh
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import pdb
import argparse
import re, os, sys

"""
Read ATCF file
Replace vmax and minp with raw values on original mesh (if model=MPAS and origmeshTrue is not in name of input file)
Plot tracks with vmax >= 34 knots 
Save figure as PNG

"""
# ifile is the name of the .trk file to modify
ifile ="/glade2/scratch2/mpasrt/uni/2018070200/latlon_0.500deg_025km/gfdl_tracker/tcgen/fort.64"
ifile ="/sysdisk1/ahijevyc/work/atcf/bwp302016.dat"
#ifile = "/glade2/work/ahijevyc/tracking_gfdl/adeck/uni/tcgen/aep162017_0.500deg_025km_gfdl_origmeshTrue_1.0d_minimum_GFDL_warmcore_only"
#ifile = "/glade/u/home/ahijevyc/origmeshTrue"

parser = argparse.ArgumentParser(description='plot tropical cyclone track/intensity from ATCF file')
parser.add_argument('-o', '--ofile', type=str, help='name of PNG output file')
parser.add_argument('--diagdir', type=str, help='path to directory with original mesh diagnostic files')
parser.add_argument('--initfile', type=str, help='path to init.nc file with latCell,lonCell,nEdgesOnCell,cellsOnCell')
parser.add_argument('ifile', type=str, help='path to ATCF file', default=ifile)
parser.add_argument('-f','--force_new', action="store_true", help='overwrite old file')
parser.add_argument('-d','--debug', action="store_true", help='print debug messages')
parser.add_argument('-v','--verbose', action="store_true", help='print more output. useful for debugging')
args = parser.parse_args()

debug = args.debug
if debug:
    print args

force_new = args.force_new
# ifile may be a relative path, so use os.path.realpath() to get absolute path, which has initial date /yyyymmddhh/
ifile = os.path.realpath(args.ifile)

# Use command line ofile if it exists.
if args.ofile:
    ofile = args.ofile
else:
    # Otherwise use tack on ".png" to ifile.
    ofile = ifile + ".png"
    
# If ofile exists and you didn't request force_new, then stop.
if os.path.isfile(ofile) and not force_new:
    print ofile, 'already exists. Use -f or --force_new to override.'
    sys.exit(1)



def category(kts):
   category = -1
   if kts > 34:
      category = 0
   if kts > 64:
      category = 1
   if kts > 83:
      category = 2
   if kts > 96:
      category = 3
   if kts > 113:
      category = 4
   if kts > 137:
      category = 5
   return category

def plot_track(track,group,scale=1,**kwargs):
    # Figure out how to skip first element
    first = True
    for index, row in group.iterrows():
        if first:
            lat0 = row.lat
            lon0 = row.lon
            first = False
            continue
        lw = 1
        if row.vmax > 34:
            lw = 3
        TScategory = category(row.vmax)
        lat1 = row.lat
        lon1 = row.lon

        # Use map() function to avoid IndexError (instead of keeping lat lon and latlon=True)
        #    thresh = 360.-londiff_sort[-2]
        #IndexError: index -2 is out of bounds for axis 0 with size 1

        x, y = m([lon0,lon1], [lat0,lat1])
        segment = m.plot(x,y, c=cmap.colors[TScategory+1],lw=lw*scale)
        lat0 = lat1
        lon0 = lon1

    # first trk_label = ID (initial fh)
    trk_label = str(track)+"\n+"+str(group.fhr.iloc[0])
    plt.text(group.lon.iloc[0],group.lat.iloc[0], trk_label, ha='center',va='top',fontsize=7*scale)
    # final trk_label = (final fh)
    plt.text(group.lon.iloc[-1],group.lat.iloc[-1], "+"+str(group.fhr.iloc[-1]), ha='center', fontsize=7*scale)


# Read data into Pandas Dataframe
print 'reading', ifile
names=["basin","cy","initial_time","technum","model","fhr","lat","lon","vmax","minp","TY",
    "rad", "windcode", "rad1", "rad2", "rad3", "rad4", "POUTER", "ROUTER", "RMW", "GUSTS", "EYE",
    "SUBREGION", "MAXSEAS", "INITIALS", "dir", "speed", "STORMNAME", "DEPTH", "SEAS", "SEASCODE",
    "SEAS1", "SEAS2", "SEAS3", "SEAS4", "USERDEFINED", "userdata"]
converters={
    "cy" :lambda x: x.strip(" ").lstrip("0"),
    "model" :lambda x: x.strip(" "),
    "vmax": float
    }
dtype={'SUBREGION': str,
       'INITIALS' : str,
       'STORMNAME' : str,
       'DEPTH':str,
       'SEAS':str,
       'SEASCODE':str,
       'USERDEFINED':str,
       'userdata':str} 

# Output from HWRF vortex tracker, fort.64 and fort.66
# are similar to ATCF format but have fewer columns
if 'fort.64' in ifile:
    names = names[0:21]

if 'fort.66' in ifile:
    names = names[0:29]
    # There is a cyclogenesis ID column for fort.66
    names.insert(2, 'id') # ID for the cyclogenesis
    names[24] = 'warmcore'

usecols = range(len(names))

# If you get a beyond index range (or something like that) error, see if userdata column is intermittent and has commas in it. 
# If so, clean it up (i.e. truncate it)
df = pd.read_csv(ifile,index_col=False,header=None, delimiter=",", usecols=usecols, names=names, converters=converters, dtype=dtype) 
# fort.64 has asterisks sometimes. Problem with hwrf_tracker. 
badlines = df['lon'].str.contains("\*")
if any(badlines):
    df = df[~badlines]

# Extract last character of lat and lon columns
# Multiply integer by -1 if "S" or "W"
# Divide by 10
S = df.lat.str[-1] == 'S'
lat = df.lat.str[:-1].astype(float) / 10.
lat[S] = lat[S] * -1
df.lat = lat
W = df.lon.str[-1] == 'W'
lon = df.lon.str[:-1].astype(float) / 10.
lon[W] = lon[W] * -1
df.lon = lon

# Derive valid time.   valid_time = initial_time + fhr
# Use datetime module to add, where yyyymmddh is a datetime object and fhr is a timedelta object.
df['valid_time'] = pd.to_datetime(df.initial_time,format='%Y%m%d%H') + pd.to_timedelta(df.fhr, unit='h')


# In case you need the original mesh values, initialize diagdir and initfile.
if args.diagdir:
    diagdir = args.diagdir
else:
    # Derive diagdir and initfile from ifile.
    idatestr = re.search("/[12]\d{9}/", ifile).end()
    # path to diagnostic file original mesh
    diagdir = ifile[:idatestr] 
if args.initfile:
    initfile = args.initfile
else:
    # path to init.nc file with latCell,lonCell,etc.
    initfile = diagdir + "init.nc"

# Perhaps ignore 50 and 64 knot rad lines. Keep 0 and 34-knot lines.Yes, there are 0-knot lines.  
df = df[df.rad <= 34]


fig, ax = plt.subplots(figsize=(18,4))
# expand domain by this many degrees
b = 2
m = Basemap(ax=ax, projection='cyl',resolution='i',
        llcrnrlon=np.max([-179,df.lon.min()-b]),
        urcrnrlon=np.min([ 179,df.lon.max()+b]),
        llcrnrlat=np.max([ -90,df.lat.min()-b]), 
        urcrnrlat=np.min([  90,df.lat.max()+b])
        )
m.shadedrelief()

dlat,dlon = 15, 15
gridlats = m.drawparallels(np.arange(0.,60.,dlat),labels=[True,True,False,False],color='white')
gridlons = m.drawmeridians(np.arange(-180.,180.,dlon),labels=[False,False,False,True],color='white')

# colors from tropicalatlantic.com
cmap = colors.ListedColormap(['white',(.01,.77,.18),(1,1,.65),(1,.85,.85),(1,.67,.67),(1,.45,.46),(1,.24,.24),(.85,.16,17)])

besttracks = any(df.model == 'BEST')
# separate best track
if besttracks:
    besttracks = df[df['model'] == 'BEST']
    df = df[df['model'] != 'BEST']



# A track has a unique combination of basin, initial_time, cy, and model.
# If one of these is constant, the track id doesn't need it. 
# Only add to groupby_list if it changes in the DataFrame.
groupby_list = [] 
title = "TC tracks"
for col in ['basin', 'initial_time','cy','model']:
    first_value = df[col].iloc[0]
    if debug: print 'first value of', col, 'is', first_value
    if all(df[col] == first_value):
        # Add this column value to title. It doesn't vary.
        title += " " + col + "= " + str(first_value)
    else:
        # if column values vary, this column can distinguish tracks
        groupby_list.append(col)

for track, group in df.groupby(groupby_list):

    # Maybe skip if it is a cyclogenesis track
    maybe_skip = track[0] == 'TG'

    if maybe_skip:
        # If warmcore column exists make sure at least one time is warmcore or unknown.
        if 'warmcore' in group.columns:
            warmcore = (group.warmcore.str.strip() == 'Y') | (group.warmcore.str.strip() == 'U')
            if warmcore.sum() == 0:
                if debug: print 'skip cold core', track
                continue
            if debug: print warmcore.sum(), '/', warmcore.size, 'warmcore lines in', track

        # Make sure vmax > 30 knots for at least one time.
        if group.vmax.max() < 30:
            if debug: print 'skip', len(group.lon), 'line', group.vmax.max(), 'kt track', track
            continue


    # Do you need the original mesh values?
    if group.model.iloc[0] == 'MPAS' and 'origmeshTrue' not in ifile:
        print 'get raw mesh vmax and minp for', len(group.lon), 'times, track', track
        # 
        # Return initfile too if you want to save the lat/lon information as a dictionary and speed things up.
        # Avoid opening and re-opening the same file over and over again.
        group, initfile = origmesh(group, initfile, diagdir, debug=debug)
        if maybe_skip and group.vmax.max() < 34:
            print 'after origmesh, skipping', len(group.lon), 'line', group.vmax.max(), 'kt track', track
            continue

    print 'plotting', track
    plot_track(track,group)
    
# Plot Best Track(s)
if besttracks:
    for track, group in besttracks.groupby(['basin','cy','model']):
        stormname = df.STORMNAME[df.vmax.idxmax]
        title = stormname + "\n" + title
        if debug: print 'plotting', stormname, 'best track'
        plot_track(stormname,group,scale=1.5)


# Set title
ax.set_title(title)
# legend screen grabbed from tropicalatlantic.com
legend = plt.imread('/glade/work/ahijevyc/share/tropicalatlantic.legend.png')
# overlay 411 pixels in and 20 pixels down from bottom left corner (cut off bottom)
fig.figimage(legend, 411, -20, origin='upper')
plt.tight_layout()

ret = mysavfig(ofile)

#plt.show()

