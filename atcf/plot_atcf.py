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

# ifile is the name of the .trk file to modify
ifile ="/glade2/scratch2/mpasrt/uni/2018062300/latlon_0.500deg_025km/gfdl_tracker/tcgen/t.64"

# Read data into Pandas Dataframe
# If you get a beyond index range (or something like that) error, see if userdata column is intermittent and has commas in it. 
# IF so, clean it up (i.e. truncate it)
df = pd.read_csv(ifile,index_col=False,header=None, delimiter=",", error_bad_lines=False,
            names=["basin","cy","yyyymmddhh","technum","model","fhr","lat","lon","vmax","minp","TY",
            "rad", "windcode", "rad1", "rad2", "rad3", "rad4", "POUTER", "ROUTER", "RMW", "GUSTS", "EYE",
            "SUBREGION", "MAXSEAS", "INITIALS", "dir", "speed", "STORMNAME", "DEPTH", "SEAS", "SEASCODE",
            "SEAS1", "SEAS2", "SEAS3", "SEAS4", "USERDEFINED", "userdata"],
        converters={
            "cy" :lambda x: x.strip(" ").lstrip("0"),
            "lat":lambda x: float(x[:-1])/10. * (1 if x[-1:] == 'N' else -1), # strip last character, convert to float, divide by 10
            "lon":lambda x: float(x[:-1])/10. * (1 if x[-1:] == 'E' else -1), # Multiply by 1 or -1
            "vmax": float
            },
        dtype={'SUBREGION': str,
               'INITIALS' : str,
               'STORMNAME' : str,
               'DEPTH':str,
               'SEAS':str,
               'SEASCODE':str,
               'USERDEFINED':str,
               'userdata':str}) 

# Derive valid time.   valid_time = yyyymmddhh + fhr
# Use datetime module to add, where yyyymmddh is a datetime object and fhr is a timedelta object.
df['valid_time'] = pd.to_datetime(df.yyyymmddhh,format='%Y%m%d%H') + pd.to_timedelta(df.fhr, unit='h')


# Perhaps ignore 50 and 64 knot rad lines
df = df[df.rad <= 34]

stormname = df.STORMNAME[df.vmax.idxmax]

initfile = "/glade2/scratch2/mpasrt/uni/2018062300/init.nc"
diagdir = "/glade2/scratch2/mpasrt/uni/2018062300/"
df = origmesh(df, initfile, diagdir)

fig, ax = plt.subplots()
# expand domain by this many degrees
b =0
m = Basemap(ax=ax, projection='cyl',resolution='i',llcrnrlon=df.lon.min()-b, urcrnrlon=df.lon.max()+b, llcrnrlat=df.lat.min()-b, urcrnrlat=df.lat.max()+b)
m.bluemarble()

dlat,dlon = 15, 15
gridlats = m.drawparallels(np.arange(0.,60.,dlat),labels=[True,True,False,False],color='white')
gridlons = m.drawmeridians(np.arange(-180.,180.,dlon),labels=[False,False,True,True],color='white')

# colors from tropicalatlantic.com
cmap = colors.ListedColormap(['white',(.01,.77,.18),(1,1,.65),(1,.85,.85),(1,.67,.67),(1,.45,.46),(1,.24,.24),(.85,.16,17)])
# approprate for atrk
#for track, group in df.groupby(['yyyymmddhh','model']):
for track, group in df.groupby(['cy']):
   if group.vmax.max() < 34:
      print 'skipping', len(group.lon), 'line track', track
      continue
   print 'looking at', track
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

      # reproject to avoid 
#Traceback (most recent call last):
#  File "plot_atcf.py", line 66, in <module>
#    fig, ax = plt.subplots()
#  File "/glade/u/apps/ch/opt/pythonpkgs/2.7/matplotlib/2.0.2/gnu/6.3.0/lib/python2.7/site-packages/mpl_toolkits/basemap/__init__.py", line 536, in with_transform
#    x = self.shiftdata(x)
#  File "/glade/u/apps/ch/opt/pythonpkgs/2.7/matplotlib/2.0.2/gnu/6.3.0/lib/python2.7/site-packages/mpl_toolkits/basemap/__init__.py", line 4775, in shiftdata
#    thresh = 360.-londiff_sort[-2]
#IndexError: index -2 is out of bounds for axis 0 with size 1

      x, y = m([lon0,lon1], [lat0,lat1])
      segment = m.plot(x,y, c=cmap.colors[TScategory+1],lw=lw)
      lat0 = lat1
      lon0 = lon1

   plt.text(group.lon[-1:],group.lat[-1:], str(track), color='white',ha='center',fontsize=10)

legend = plt.imread('/glade/work/ahijevyc/share/tropicalatlantic.legend.png')
fig.figimage(legend, 0, 0)

def on_xlims_change(axes):
   print "updated xlims: ", axes.get_xlim()

ax.callbacks.connect('xlim_changed', on_xlims_change)
plt.show()

