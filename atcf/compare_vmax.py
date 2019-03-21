import atcf
import pdb
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import argparse
import datetime

# provide list of filenames on command line. These, along with their _origmeshTrue counterparts, will be processed.


parser = argparse.ArgumentParser(description='scatter plot of vmax from ECMWF TIGGE and official adeck')
parser.add_argument('-d','--debug', action="store_true", help='print debug messages')
parser.add_argument('--gs', type=float, default=0.5, help='TIGGE data interpolated to this grid spacing in degrees')
parser.add_argument('input_files', type=str, nargs='+', help="input files without _origmeshTrue suffix")
args = parser.parse_args()
debug = args.debug
gs    = args.gs

# Run in /glade/work/ahijevyc/atcf/Irma2017 directory

fig, ax = plt.subplots()
dates = []
for input_file in args.input_files: 
    x = atcf.read(input_file)
    # The adeck has 2 more models than origmeshTrue: ECMF and EE00.
    x = x[x.model != 'EE00']
    x = x[x.model != 'ECMF']
    # Read vmax/mslp from original mesh
    y = atcf.read(input_file+"_origmeshTrue",debug=debug)
    y = y[y.rad <= 34]
    # match lines from original adeck and origmeshTrue.
    z = pd.merge(x, y, on=['model','fhr']) 
    # Get first initialization time in yyyymmddhh formatted string.
    date = x.initial_time.dt.strftime('%Y%m%d%H').iloc[0]
    dates.append(date)
    sc = ax.scatter(z.vmax_x, z.vmax_y, alpha=0.05,label=date, s=1.8, marker="s", color="blue")


lim = np.array([0, 150])
# 1:1 or 100% line
oo = ax.plot(lim,lim,"k--",label="100% of adeck",zorder=0, linewidth=0.8)
# 80% underestimate line
oo = ax.plot(lim,lim*0.8,"k", linestyle='dotted',label="80% of adeck",zorder=0,linewidth=0.5)
# 50% underestimate line
oo = ax.plot(lim,lim*0.5,"k", linestyle='dotted',label="50% of adeck",zorder=0,linewidth=0.3)
cats = plt.axvline(34,label='TC strength',zorder=0,alpha=0.5)
l = ax.legend(fontsize='7')
cats = plt.axhline(34,zorder=0, alpha=0.5)
ax.set_xlabel("Vmax (kts) from adeck (native resolution ~18km)")
ax.set_ylabel("Vmax (kts) from TIGGE")
ax.set_xlim(lim)
ax.set_ylim(lim)

plt.title("Vmax on native ECMWF mesh vs. "+str(gs)+" deg lat-lon grid")
date_range = max(dates)
if min(dates) != max(dates):
    date_range = min(dates)+"-"+max(dates)
ofile = "compare_vmax."+str(gs)+"."+date_range+".png"
string = "\ncreated "+str(datetime.datetime.now(tz=None)).split('.')[0]
plt.annotate(s=string, xy=(20,2), xycoords='figure pixels', fontsize=5)
print("savefig", ofile)
plt.savefig(ofile, dpi=200)
ax.clear()
