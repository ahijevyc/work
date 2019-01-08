import atcf
import pdb
import pandas as pd
import matplotlib.pyplot as plt


# Run in /glade/work/ahijevyc/atcf/tmp directory

fig, ax = plt.subplots()
for i,date in enumerate(["2017090600", "2017090700", "2017090800", "2017090900"]):
    x = atcf.read(date+".dat")
    # The adeck has 2 more models than origmeshTrue: ECMF and EE00.
    x = x[x.model != 'EE00']
    x = x[x.model != 'ECMF']
    y = atcf.read(date+".dat_origmeshTrue")
    y = y[y.rad <= 34]
    # match lines from original adeck and origmeshTrue.
    z = pd.merge(x, y, on=['model','fhr']) 
    sc = ax.scatter(z.vmax_x, z.vmax_y, alpha=0.3,label=date, s=2)

oo = ax.plot((0,140),(0,140),"k--",label="1:1 line",zorder=0)
oo = ax.plot((0,140),(0,140*0.8),"k", linestyle='dotted',label="1:0.8 line",zorder=0)
cats = plt.axvline(34,label='34 kts',zorder=0,alpha=0.5)
l = ax.legend()
cats = plt.axhline(34,zorder=0, alpha=0.5)
ax.set_xlabel("vmax (kts) from adeck")
ax.set_ylabel("vmax (kts) from 0.5deg TIGGE")

plt.title("ECMWF ensemble winds for Irma")
ofile = "compare_vmax.png"
print "savefig", ofile
plt.savefig(ofile, dpi=200)
