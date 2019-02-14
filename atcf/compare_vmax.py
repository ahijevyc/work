import atcf
import pdb
import pandas as pd
import matplotlib.pyplot as plt
import argparse


parser = argparse.ArgumentParser(description='scatter plot of vmax from ECMWF TIGGE and official adeck')
parser.add_argument('-d','--debug', action="store_true", help='print debug messages')
args = parser.parse_args()
debug = args.debug

# Run in /glade/work/ahijevyc/atcf/Irma2017 directory

fig, ax = plt.subplots()
# Isotropic axes
plt.axis('equal')
ax.margins(0)
for i,date in enumerate(["2017090512", "2017090600", "2017090612", "2017090700", "2017090712", "2017090800", "2017090812", "2017090900", "2017090912"]):
    x = atcf.read(date+".dat")
    # The adeck has 2 more models than origmeshTrue: ECMF and EE00.
    x = x[x.model != 'EE00']
    x = x[x.model != 'ECMF']
    # Read vmax/mslp from original mesh
    y = atcf.read(date+".dat_origmeshTrue",debug=debug)
    y = y[y.rad <= 34]
    # match lines from original adeck and origmeshTrue.
    z = pd.merge(x, y, on=['model','fhr']) 
    sc = ax.scatter(z.vmax_x, z.vmax_y, alpha=0.05,label=date, s=1.8, marker="s", color="blue")


xlim = ax.get_xlim()
# 1:1 or 100% line
oo = ax.plot(xlim,xlim,"k--",label="100% of adeck",zorder=0, linewidth=0.8)
# 80% underestimate line
oo = ax.plot(xlim,(xlim[0], xlim[1]*0.8),"k", linestyle='dotted',label="80% of adeck",zorder=0,linewidth=0.5)
# 50% underestimate line
oo = ax.plot(xlim,(xlim[0], xlim[1]*0.5),"k", linestyle='dotted',label="50% of adeck",zorder=0,linewidth=0.3)
cats = plt.axvline(34,label='TC strength',zorder=0,alpha=0.5)
l = ax.legend(fontsize='7')
cats = plt.axhline(34,zorder=0, alpha=0.5)
ax.set_xlabel("Vmax (kts) from adeck (native resolution ~18km)")
ax.set_ylabel("Vmax (kts) from TIGGE (0.5deg)")
ax.set_ylim(top=140)

plt.title("Effect of interpolating wind from 18 to 50km for Irma")
ofile = "compare_vmax.png"
print("savefig", ofile)
plt.savefig(ofile, dpi=200)
ax.clear()
