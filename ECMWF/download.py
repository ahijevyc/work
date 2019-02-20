#!/usr/bin/env python
from ecmwfapi import ECMWFDataServer # run this script in /glade/work/ahijevyc/ECMWF/. to find ecmwfapi module
import os
import pandas as pd


# input: list or array
# output: single string with elements of input list joined by slashes
def tostr(a):
    str_a = [str(x) for x in a]
    return '/'.join(str_a)


# Directory to download into
def outdir(date):
    yyyymmddhh = date.strftime('%Y%m%d%H')
    return "/glade/scratch/ahijevyc/ECMWF/"+yyyymmddhh+"/"



server = ECMWFDataServer()
# TIGGE ensemble member resolution varies by latitude but is equivalent to about 18 km grid spacing. 
grid="0.15" 
sgrid = grid.replace(".","p")
ftype="pf" # fc=hi-res deterministic forecast, cf=ensemble control forecast, pf=ensemble perturbed forecast

# forecast lead times
step = '0/TO/216/BY/6'

# If you request all 50 at once, the amount may exceed the MARS server threshold.
# You could download one member at a time to reduce request size. But it is inefficient breaking
# up what probably is a one-tape request into multiple requests. 
ens_members_str='1/TO/50/BY/1'

# mslet is "membrane" mslp or Eta model reduction. NHC asked Tim Marchok to use.
# I'm not even sure it is available in TIGGE.
ADCIRC_sfc_param = "10u/10v/msl"
basic_sfc_param = "sshf/slhf/msl/10u/10v/2t/2d" 
more_sfc_param  = "cape/mx2t6/mn2t6/sp/tcw/sshf/slhf/msl/10u/10v/2t/2d/lsm/ssr/str/ttr/sund/skt/cin/orog/sm/st/sd/sf/tcc/tp"


# Create date range and make output directories, if needed.
date_range = pd.date_range('9/08/2017', periods=1, freq='12H')
for date in date_range:
    opath = outdir(date)
    if not os.path.exists(opath):
        print("making "+opath)
        os.makedirs(opath)



# Group requests by level type first.
# This matches the tree structure of the MARS tape archive and is more efficient.
pressure_level      = False
surface             = True
potential_vorticity = False



# common key:value pairs in retrieve dictionary
retrieve_dict = {
        "class": "ti",
        "dataset": "tigge",
        "expver": "prod",
        "grid": grid+"/"+grid,
        "origin": "ecmf",
        }


# Iterate over dates within each level type.
if surface:
    for date in date_range:
        target = outdir(date) + sgrid + date.strftime('%Y%m%d%H') + "_sfc.grb"

        # Ensemble surface data
        
        retrieve_dict.update({
            "date": date.strftime('%Y%m%d'),
            "levtype": "sfc",
            "number": ens_members_str,
            "param": ADCIRC_sfc_param,
            "step": step,
            "target": target, 
            "time": date.hour,
            "type": "pf"
        })
        server.retrieve(retrieve_dict)

        if False:
            # More surface data
            # type:control forecast. not available as part of perturbed forecast ensemble
            # LANDSEA
            target = outdir(date) + sgrid + date.strftime('%Y%m%d%H') + "_sfc2.grb"
            retrieve_dict.update({
                "date": date.strftime('%Y%m%d'),
                "levtype": "sfc",
                "param": "lsm/orog",
                "step": step,
                "target": target,
                "time": date.hour,
                "type": "cf"
            })
            server.retrieve(retrieve_dict)

if potential_vorticity:
    for date in date_range:
        target = outdir(date) + sgrid + date.strftime('%Y%m%d%H') + "_pv.grb"
        # potential temperature (pt),  u and v wind
        retrieve_dict.update({
              "date": date.strftime('%Y%m%d'),
              "levelist": "2",
              "levtype": "pv",
              "param": "pt/u/v",
              "step": step,
              "target": target,
              "time": date.hour,
              "type": ftype,
        })
        server.retrieve(retrieve_dict)


if pressure_level:
    for date in date_range:
        target = outdir(date) + sgrid + date.strftime('%Y%m%d%H') + "_pl.grb"
        levelist = "1000/925/850/700/500/300/250/200"
        retrieve_dict.update({
              "date": date.strftime('%Y%m%d'),
              "levtype": "pl",
              "number": ens_members_str,
              "levelist": levelist,
              "param": "t/u/v/q/gh",
              "step": step,
              "target": target,
              "time": date.hour,
              "type": ftype,
        })
        server.retrieve(retrieve_dict)

