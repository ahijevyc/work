#!/usr/bin/env python

# pip install ecmwf-api-client to find ecmwfapi module
import os
import pandas as pd
import argparse
import pdb


#=============Arguments===================
parser = argparse.ArgumentParser(description = "download grib2 ECMWF ensemble from TIGGE", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("init_start", type=str, help='first initialization date/time')
parser.add_argument("init_end", type=str, help='last initialization date/time')
parser.add_argument("valid_end", type=str, help='last valid date/time')
args = parser.parse_args()
init_start = args.init_start
init_end = args.init_end
valid_end = args.valid_end

# Directory to download into
def outdir(date,sgrid):
    yyyymmddhh = date.strftime('%Y%m%d%H')
    return "/glade/scratch/ahijevyc/ECMWF/"+sgrid+"/"+yyyymmddhh+"/"

def retrieve(request):
    """ Execute Mars request

    Parameters
    ----------
    request

    Returns
    -------
    filename
    """
    from ecmwfapi import ECMWFDataServer
    server = ECMWFDataServer()

    # Make output directory if it doesn't exist
    odir = os.path.dirname(request['target'])
    if not os.path.isdir(odir):
        os.makedirs(odir)

    try:
        server.retrieve(request)
        print("Request was successful.")
        return request['target']

    except Exception as e:
        print(repr(e))
        return False

# TIGGE ensemble member resolution varies by latitude but is equivalent to about 18 km grid spacing. 
grid = "0.125" 
sgrid = grid.replace(".","p")

# Not sure if it makes sense to define file type up here. Sometimes it is hard-coded below.
# fc = hi-res deterministic forecast
# cf = ensemble control forecast
# pf = ensemble perturbed forecast
ftype = "pf" 


# Extract limited area
# area : North/West/South/East
area  = "50/-110/-5/-20" # for 2017 Irma
area  = "50/-110/-5/-30"


# If you request all 50 at once, the amount may exceed the MARS server threshold.
# You could download one member at a time to reduce request size. But it is inefficient
# to break up what is probably a one-tape request into multiple requests. 
ens_members_str='1/TO/50/BY/1'

# Create date range
idate_range = pd.date_range(start=init_start, end=init_end, freq='12H')

def last_fhr(idate, valid_end):
    d = pd.to_datetime(valid_end) - pd.to_datetime(idate)
    return str(d.total_seconds()/3600)

# level type flags
pressure_level      = False
surface             = True
potential_vorticity = False

#################################################################
# shouldn't have to modify below here very often
#################################################################

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

# Generate multiple target files using Mars keywords in square brackets. see https://confluence.ecmwf.int/pages/viewpage.action?pageId=116968972
# Set env var for leading zeros.
# This didn't work. All it did was save one file with the substring [step].
os.environ["MARS_MULTITARGET_STRICT_FORMAT"] = "1" 

# Group requests by level type first.
# Then iterate over dates within each level type.
# This matches the tree structure of the MARS tape archive and is more efficient.

if pressure_level:
    for date in idate_range:
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_pl.grb"
        levelist = "1000/925/850/700/500/300/250/200"
        # forecast lead times
        retrieve_dict["step"] = '0/TO/'+last_fhr(date,valid_end)+'/BY/6'
        retrieve_dict.update({
            "date": date.strftime('%Y%m%d'),
            "levtype": "pl",
            "number": ens_members_str,
            "levelist": levelist,
            "param": "t/u/v/q/gh",
            "target": target,
            "time": date.hour,
            "type": ftype
        })
        ret = retrieve(retrieve_dict)

if surface:
    for date in idate_range:
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_sfc.grb"
        # forecast lead times
        retrieve_dict["step"] = '0/TO/'+last_fhr(date,valid_end)+'/BY/6'

        # Ensemble surface data
        retrieve_dict.update({
            "date": date.strftime('%Y%m%d'),
            "levtype": "sfc",
            "number": ens_members_str,
            "param": ADCIRC_sfc_param,
            "target": target, 
            "time": date.hour,
            "type": "pf"
        })
        ret = retrieve(retrieve_dict)

        if False:
            # More surface data
            # type:control forecast. not available as part of perturbed forecast ensemble
            # LANDSEA
            target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_sfc2.grb"
            retrieve_dict.update({
                "date": date.strftime('%Y%m%d'),
                "levtype": "sfc",
                "param": "lsm/orog",
                "target": target,
                "time": date.hour,
                "type": "cf"
            })
            ret = retrieve(retrieve_dict)

if potential_vorticity:
    for date in idate_range:
        target = outdir(date,sgrid) + sgrid + date.strftime('%Y%m%d%H') + "_pv.grb"
        # forecast lead times
        retrieve_dict["step"] = '0/TO/'+last_fhr(date,valid_end)+'/BY/6'
        # potential temperature (pt),  u and v wind
        retrieve_dict.update({
            "date": date.strftime('%Y%m%d'),
            "levelist": "2",
            "levtype": "pv",
            "param": "pt/u/v",
            "target": target,
            "time": date.hour,
            "type": ftype
        })
        ret = retrieve(retrieve_dict)


