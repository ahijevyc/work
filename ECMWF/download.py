#!/usr/bin/env python

# run this script in /glade/work/ahijevyc/ECMWF/. to find ecmwfapi module
from ecmwfapi import ECMWFDataServer
import os
import pandas as pd

server = ECMWFDataServer()

# input: list or array
# output: single string with elements of input list joined by slashes
def tostr(a):
    str_a = [str(x) for x in a]
    return '/'.join(str_a)

# Directory to download into
def outdir(date,sgrid):
    yyyymmddhh = date.strftime('%Y%m%d%H')
    return "/glade/scratch/ahijevyc/ECMWF/"+yyyymmddhh+"/"+sgrid+"/"


# TIGGE ensemble member resolution varies by latitude but is equivalent to about 18 km grid spacing. 
grid = "0.25" 
sgrid = grid.replace(".","p")

# Not sure if it makes sense to define file type up here. Sometimes it is hard-coded below.
# fc = hi-res deterministic forecast
# cf = ensemble control forecast
# pf = ensemble perturbed forecast
ftype = "pf" 

# forecast lead times
step = '0/TO/144/BY/6'

# Extract limited area
# area : North/West/South/East
area  = "50/-110/-5/-20" # for 2017 Irma


# If you request all 50 at once, the amount may exceed the MARS server threshold.
# You could download one member at a time to reduce request size. But it is inefficient
# to break up what is probably a one-tape request into multiple requests. 
ens_members_str='1/TO/50/BY/1'

# Create date range
date_range = pd.date_range('9/08/2017 00', periods=1, freq='12H')


# level type flags
pressure_level      = False
surface             = True
potential_vorticity = False

#################################################################
# shouldn't have to modify below here very often
#################################################################

# make output directories, if needed.
for date in date_range:
    opath = outdir(date,sgrid)
    if not os.path.exists(opath):
        print("making "+opath)
        os.makedirs(opath)


# Named groups of surface parameters
# mslet is Eta model reduction, or "membrane" mslp. 
# NHC asked Tim Marchok to use mslet for tracking GFS TCs.
# I'm not even sure it is available in TIGGE.
ADCIRC_sfc_param = "10u/10v/msl" # wind and mean sea level pressure
basic_sfc_param = "sshf/slhf/msl/10u/10v/2t/2d" 
more_sfc_param  = "cape/mx2t6/mn2t6/sp/tcw/sshf/slhf/msl/10u/10v/2t/2d/lsm/ssr/str"
more_sfc_param += "/ttr/sund/skt/cin/orog/sm/st/sd/sf/tcc/tp"


# common key:value pairs in retrieve dictionary
retrieve_dict = {
        "class": "ti",
        "dataset": "tigge",
        "expver": "prod",
        "grid": grid+"/"+grid,
        "origin": "ecmf",
        "area"  : area
        }


# Group requests by level type first.
# Then iterate over dates within each level type.
# This matches the tree structure of the MARS tape archive and is more efficient.

if pressure_level:
    for date in date_range:
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_pl.grb"
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
            "type": ftype
        })
        server.retrieve(retrieve_dict)

if surface:
    for date in date_range:
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_sfc.grb"

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
            target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_sfc2.grb"
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
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_pv.grb"
        # potential temperature (pt),  u and v wind
        retrieve_dict.update({
            "date": date.strftime('%Y%m%d'),
            "levelist": "2",
            "levtype": "pv",
            "param": "pt/u/v",
            "step": step,
            "target": target,
            "time": date.hour,
            "type": ftype
        })
        server.retrieve(retrieve_dict)


