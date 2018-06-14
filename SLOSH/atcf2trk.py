import numpy as np
import pandas as pd
import pdb

# Copied SLOSH_trk.py from tuna to cheyenne Jun 11, 2018

# Read ATCF file
# Derive valid time and pressure deficit, dP.

# Manipulate it
# Write SLOSH .trk file.

# ifile is the name of the .trk file to modify
ifile = "/glade/work/ahijevyc/atcf/bal112017.dat"

# ofile is the name of the new file.
ofile = ifile + ".trk"


# Read data into Pandas Dataframe
df = pd.read_csv(ifile,index_col=False, 
        delimiter=",",names=["basin","cy","yyyymmddhh","technum","model","fhr","lat","lon","vmax","minp","TY",
            "rad", "windcode", "rad1", "rad2", "rad3", "rad4", "POUTER", "ROUTER", "RMW", "GUSTS", "EYE",
            "SUBREGION", "MAXSEAS", "INITIALS", "dir", "speed", "STORMNAME", "DEPTH", "SEAS", "SEASCODE",
            "SEAS1", "SEAS2", "SEAS3", "SEAS4", "USERDEFINED", "userdata"],
        converters={
            "lat":lambda x: float(x[:-1])/10., # strip last character, convert to float, divide by 10 
            "lon":lambda x: float(x[:-1])/10.,
            "vmax": float
            }) 

# Derive valid time.   valid_time = yyyymmddhh + fhr
# Use datetime module to add, where yyyymmddh is a datetime object and fhr is a timedelta object.
df['valid_time'] = pd.to_datetime(df.yyyymmddhh,format='%Y%m%d%H') + pd.to_timedelta(df.fhr, unit='h')

#Convert from knots to mph
kts2mph = 1.15078
df['vmax_mph'] = df['vmax'] * kts2mph
# bearing is equivalent to dir, (right?)
df['bearing'] =  df['dir']

def haversine(lon, lat):

    # Input lon and lat Series or numpy arrays
    
    radius = 6371 # km radius of Earth

    # Convert degrees to radians
    lon = np.radians(lon)
    lat = np.radians(lat)
    
    dlat = lat.diff()
    dlon = lon.diff()

    lat1 = lat.shift(1) # lat1's elements are shifted 1 to right
    # lat - lat1 = dlat

    a = np.sin(dlat/2) * np.sin(dlat/2) + np.cos(lat1) \
        * np.cos(lat) * np.sin(dlon/2) * np.sin(dlon/2)
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
    d = radius * c

    bearing = np.arctan2(np.sin(dlon)*np.cos(lat), np.cos(lat1)*np.sin(lat) - np.sin(lat1)*np.cos(lat)*np.cos(dlon)) 

    # convert from radians to degrees
    bearing = np.degrees(bearing)

    # -180 - 180 -> 0 - 360
    # Don't know if I got the definition of bearing and heading right
    # For some reason I have to negate bearing .
    # Something about mathematical vs meteorological direction?
    bearing = (-bearing + 360) % 360
    return d, bearing


# Convert from nautical miles to statute (normal) miles
nautical_miles2statute_miles = kts2mph 
df['RMW'] = df['RMW'] * nautical_miles2statute_miles 

# Derive dP (pressure change from ambient).
ambient = 1013.
df['dP'] = 1013 - df['minp']


# Bunch of blank entries
df['NAP'] = ''
df['NAP2'] = ''


# Make valid time the official index of this Dataframe.
df.set_index(df.valid_time,inplace=True)

# Throw away lines with duplicated valid time (max radii of 50-knot wind, 64-knot wind)
df = df[~df.index.duplicated(keep='first')]

if all(df.bearing == 0) and all(df.speed == 0):
    print "all bearing/speeds are zero. Derive from lat/lon"
    dist, bearing = haversine(df.lon, df.lat)
    dtime = df.valid_time.diff() / np.timedelta64(1, 's')
    kms2knots = 1943.84 # km per sec to knots
    df.speed = dist/dtime * kms2knots
    df.bearing = bearing


# Create evenly-spaced time series
# freq='1H' means every hour
x2 = pd.date_range(df.valid_time.iloc[0], df.valid_time.iloc[-1], freq='1H')
df = df.reindex(x2)

# Interpolate everything to evenly-spaced time series
df = df.interpolate(method='linear') # interpolate works for numbers; for non-numbers it puts NaN
df = df.fillna(method='pad') # for non-numbers (like basin string) just pad with the one above


# Define header and footer
maxdP = df["dP"].max()
minP = df["minp"].min()

header  = " HURRICANE IRMA: NHC BEST TRACK     DATUMS = 2.0 FT.\n" + \
        " DELTA-P = " + '{:.0f}'.format(maxdP) + "MB:(1013-" + '{:.0f}'.format(minP) + " MB); RMW=10\n" 

footer = ' 47 84 70                IBGNT ITEND JHR\n'
footer += 'HR0200 11 SEP 2017       NEAREST APPROACH, OR LANDFALL, TIME\n'
footer += '  2.0  2.0               SEA AND LAKE DATUM\n'

# Strip down to only the columns you need for *.trk file.
df = df[['NAP','lat','lon','vmax_mph','speed','bearing','dP','RMW','NAP2']]

# Modify data
#df.lat= df.lat- 1





# Extract middle 100 rows.
df = df.iloc[200:300]

df.NAP[69] = 'NAP-----'
df.NAP2[69] = '---NAP'

# Define simple index column (1-100).
nrows = df['NAP'].size
df['i_index'] = np.arange(nrows) + 1
# Define strange j_index column (1-21,0-72,1-6)
df['j_index'] = np.arange(nrows) + 1
df['j_index'][21:21+73].value = np.arange(73)
df['j_index'][-6:].value = np.arange(6) + 1


# Reorder columns
df = df[['NAP','i_index','lat','lon','speed','bearing','dP','RMW','j_index','NAP2']]


# Format output into neat columns.
# In the format string between the curly brackets, spaces are important.
# na_rep='' replaces not-a-number (NaN) with empty string.
x = df.to_string(header=False,index=False,na_rep='',
   formatters={
      'NAP'      :   '{:>15}'.format,
      'i_index'  : '{: 4.0f}'.format,
      'lat'      :  '{:7.4f}'.format,
      'lon'      : '{: 7.3f}'.format,
      'speed'    : '{: 7.2f}'.format,
      'bearing'  : '{: 7.2f}'.format,
      'dP'       : '{: 7.2f}'.format,
      'RMW'      : '{: 7.2f}'.format,
      'j_index'  : '{: 4.0f}'.format,
   }
)


# Write output file
f = open(ofile, "w+")
f.write(header)
f.write('                   ')
f.write(x)
f.write('\n')
f.write(footer)
f.close()
print "wrote", ofile
