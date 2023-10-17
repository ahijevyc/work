load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_inv_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

undef("spdhed")

; function spdhed (speed and heading)
; Input:
;     inlat   - scalar or array of latitude in degrees.
;     inlon   - scalar or array of longitude in degrees.
;     indata  - data object with valid time array attached as attribute indata@valid
;     res     - resource with optional attributes, like plus_minus_hrs
; 
; Returns:
;    data   - variable with attributes 
;    These attributes are same size as input.
;     data@speed  - scalar or array of speeds in m/s
;       average speed over a time window centered on each element of 
;       inhours. The time window is plus_minus_hrs hours.
;       if inhours[n]-plus_minus_hrs < inhours[0], then use 
;       inhours[0] as first part of time window.
;       Similarly, if inhours[n]+plus_minus_hrs > inhours[last]
;       then use the inhours[last] as end of time window.
;     data@heading - scalar or array of headings in degrees
;       heading is opposite of wind direction.
;       A heading=270 means it is heading west.
;     data@U - zonal component of movement (m/s)
;     data@V - meridional component of movement (m/s)
;     data@units - "m/s"
;     data@plus_minus_hrs - half-width of time window over
;       which average speed is calculated.
; 
;
function spdhed(inlat,inlon,indata,res)
local r,lat,lon,valid
begin
    ; Make copies of input variables.

    lat         = inlat
    lon         = inlon
    valid       = indata@valid ; Don't use fhr; for best track they are all zero
    valid@units = indata@timeunits

    if (res) then
        r = res
    else
        r = True
    end if

    ; plus_minus_hrs = plus and minus time interval for velocity calculation.
    plus_minus_hrs = 6; default
    ; returned as data@plus_minus_hrs attribute
    if (isatt(r,"plus_minus_hrs"))then
        plus_minus_hrs = r@plus_minus_hrs
    end if
 
    debug = False ; default
    if (isatt(r,"debug"))then
        debug = r@debug
    end if


    ; ATCF sometimes has 0-kt, 34-kt, 50-kt, and 64-kt lines all for the same time.
    ; I want to allow for repeated lines for the same time in the calculations below. 

    n = dimsizes(lat)
    ; Sanity check. Make sure input arrays are all the same size.
    if(any(n.ne.dimsizes(lon)).or.any(n.ne.dimsizes(valid)))then
        print("spdhed: lat, lon, and valid must be same size")
        printVarSummary(lat)
        printVarSummary(lon)
        printVarSummary(valid)
    end if
    ds = new(n,double)
    dhr = new(n,double)
    heading = new(n,float)
    speed = new(n,double)

    iplust = ind( valid-valid(0) .ge. plus_minus_hrs)
    if(any(ismissing(iplust)))then
        print(valid)
        print("no time at least "+plus_minus_hrs+" hours later than first time.")
        exit
    end if
    iplust := iplust(0)

    iminst0 = ind( valid-valid(n-1) .le. -plus_minus_hrs)
    if(any(ismissing(iminst0)))then
        print("no time at least "+plus_minus_hrs+" hours earlier than last time.")
        exit
    end if
    iminst0 := max(iminst0)

    ; Fill in speed and heading of first time using displacement from first time to second time. 
    ds(0:iplust-1) = gc_latlon(lat(0),lon(0),lat(iplust),lon(iplust),2,3); last arg 3=meters
    dhr(0:iplust-1) = valid(iplust)-valid(0)
    ; Return the angle between a unit vector pointing due north from point A and a
    ; great circle from point A and ending at point C.
    ; Returned angle is positive if C is west of A and negative if C is east of A.
    ; That is the opposite of meteorological heading so we multiply by -1 below.
    heading(0:iplust-1) = gc_dangle((/lat(0),lat(0)+1,lat(iplust)/), (/lon(0),lon(0),lon(iplust)/))
    if(debug.or.dhr(0).ne.plus_minus_hrs)then
        print(lat)
        print(lon)
        print(valid)
        print(cd_string(valid,""))
        print(iminst0)
        print(iplust)
    end if
    ; Loop through middle times 
    ; calculate speed/heading between earlier and later times (at least by plus_minus_hrs)
    do i=iplust,iminst0
        iminst := ind( valid-valid(i) .le. -plus_minus_hrs)
        iplust := ind( valid-valid(i) .ge.  plus_minus_hrs)
        if(any(ismissing(iminst)))then
            print("spdhed: no time at least -"+plus_minus_hrs+" hours from "+cd_string(valid(i),""))
            print("i="+tostring(i)+", iminst="+tostring(iminst))
            continue ; leave displacement ds(i) and time interval dhr(i) missing
        end if
        if(any(ismissing(iplust)))then
            print("spdhed: no time at least +"+plus_minus_hrs+" hours from "+cd_string(valid(i),""))
            print("i="+tostring(i)+", iplust="+tostring(iplust))
            continue ; leave displacement ds(i) and time interval dhr(i) missing
        end if
        iminst := max(iminst)
        iplust := min(iplust)

        ds(i) = gc_latlon(lat(iminst),lon(iminst),lat(iplust),lon(iplust),2,3); last arg 3=meters
        heading(i) = gc_dangle((/lat(iminst),lat(iminst)+1,lat(iplust)/), (/lon(iminst),lon(iminst),lon(iplust)/))
        dhr(i) = valid(iplust)-valid(iminst)
    end do
    ; fill in last time with speed and heading between 2nd-to-last time and last time.
    ; pick up with index i. It is the first line of the last time.
    ; i-i is the index of the 2nd-to-last time.
    ds(i:) = gc_latlon(lat(i-1),lon(i-1),lat(i),lon(i),2,3); last arg 3=meters
    heading(i:) = gc_dangle((/lat(i-1),lat(i-1)+1,lat(i)/), (/lon(i-1),lon(i-1),lon(i)/))
    dhr(i:) = valid(i)-valid(i-1)
    heading = mod(-heading + 360,360)
    j := ind(dhr.ne.0)
    speed(j) = ds(j)/dhr(j)/3600.
    if(debug)then
        ff = 6
        print("first "+ff+" times...ds, dhr, heading, speed")
        print(ds(:ff)+", "+dhr(:ff)+", "+heading(:ff)+", "+speed(:ff))
        print("last "+ff+" times...")
        print(ds(i-ff:)+", "+dhr(i-ff:)+", "+heading(i-ff:)+", "+speed(i-ff:))
    end if
    data = True
    data@units = "m/s"
    data@speed = speed
    data@heading = heading
    ; heading is opposite of wind direction
    tmp = wind_component(speed, heading+180., 0)
    data@U = tmp(0,:)
    data@V = tmp(1,:)
    data@plus_minus_hrs = plus_minus_hrs
    return(data)
end

undef("read_atcf")
function read_atcf(filename:string)
; Define local variables. We do not want these to be accessible outside the scope of the function.
local fhr, lat, lon, vmax, mslp, rad, stormname
begin
    
    basin := systemfunc("cut -f1 -d, " + filename)
    sid := systemfunc("cut -f2 -d, " + filename)

    ; Count number of columns to guess how to read it
    ncols = systemfunc("head -n 1 " + filename+" | wc -w")
    if(ncols.eq.0)then
        print(filename)
        print("ncols=0")
        exit
    end if
    ; Read lat/lon speed and pressure
    if(any(ncols.eq.(/10,11/)))then ; WRF copied and pasted from Kowaleski's excel spreadsheet (10) and ADECK from Ryan Torn (11)
        ; Read Time stamps
        yyyymmddhh_init = str_left_strip(systemfunc("cut -f3 -d, " + filename)) ; first character is space
        init = cd_inv_string(yyyymmddhh_init,"%Y%N%D%H")
        fhr = stringtofloat(systemfunc("cut -f6 -d, " + filename))
        lat = systemfunc("cut -f7 -d, " + filename)
        lon = systemfunc("cut -f8 -d, " + filename)
        vmax = stringtofloat(systemfunc("cut -f9 -d, " + filename)) 
        mslp = stringtofloat(systemfunc("cut -f10 -d, " + filename))
        rad = new(dimsizes(mslp),"float")
    end if
    if(ncols.eq.31)then ; fort.66 style
        ; Read Time stamps
        yyyymmddhh_init = str_left_strip(systemfunc("cut -f4 -d, " + filename)) ; first character is space
        init = cd_inv_string(yyyymmddhh_init,"%Y%N%D%H")
        fhr = stringtofloat(systemfunc("cut -f7 -d, " + filename))
        lat = systemfunc("cut -f8 -d, " + filename)
        lon = systemfunc("cut -f9 -d, " + filename)
        vmax = stringtofloat(systemfunc("cut -f10 -d, " + filename)) 
        mslp = stringtofloat(systemfunc("cut -f11 -d, " + filename))
        rad = stringtofloat(systemfunc("cut -f13 -d, " + filename))
    end if
    if(any(ncols.eq.(/17,20,22,23,29,36,37,40,41,43,44,45,46,47,48/)))then ; fort.69 style - also best track
        ; Read Time stamps
        yyyymmddhh_init = str_left_strip(systemfunc("cut -f3 -d, " + filename)) ; first character is space
        init = cd_inv_string(yyyymmddhh_init,"%Y%N%D%H")
        fhr = stringtofloat(systemfunc("cut -f6 -d, " + filename))
        lat = systemfunc("cut -f7 -d, " + filename)
        lon = systemfunc("cut -f8 -d, " + filename)
        vmax = stringtofloat(systemfunc("cut -f9 -d, " + filename)) 
        mslp = stringtofloat(systemfunc("cut -f10 -d, " + filename))
        rad = stringtofloat(systemfunc("cut -f12 -d, " + filename))
        stormname = str_strip(systemfunc("cut -f28 -d, " + filename))
    end if
    if(any(ncols.eq.(/38,39,49/)) )then ; ADCIRC fort.22 style (yyyymmddhh is not initialization time, but valid time
        ; Read Time stamps
        yyyymmddhh_valid = str_left_strip(systemfunc("cut -f3 -d, " + filename)) ; first character is space
        fhr = stringtofloat(systemfunc("cut -f6 -d, " + filename))
        init = cd_convert(cd_inv_string(yyyymmddhh_valid,"%Y%N%D%H"),"hours since 1970-01-01 00:00:00")
        init = init - fhr
        lat = systemfunc("cut -f7 -d, " + filename)
        lon = systemfunc("cut -f8 -d, " + filename)
        vmax = stringtofloat(systemfunc("cut -f9 -d, " + filename)) 
        mslp = stringtofloat(systemfunc("cut -f10 -d, " + filename))
        rad = stringtofloat(systemfunc("cut -f12 -d, " + filename))
        heading = stringtofloat(systemfunc("cut -f26 -d, " + filename))
        speed   = stringtofloat(systemfunc("cut -f27 -d, " + filename))
    end if

    ; Sanity check . Should be just one storm in here.
    if(any(basin.ne.basin(0)).or.any(sid.ne.sid(0)))then
        print("read_atcf expects just one storm in file.")
        print("check "+filename)
        exit
    end if
    if(.not.isvar("fhr"))then
        print("read_atcf.ncl: why is fhr not defined?")
        print("tried to read "+filename)
        print(ncols)
    end if
    if(all(fhr.eq.0))then
        print("read_atcf.ncl: fhr all zeroes.")
        print("Assuming "+filename+" is best track")
    end if
    if(max(fhr).gt.480)then
        ; if fhr exceeds 480 assume it is of form hhhmm.
        fhr=fhr/100 + (fhr - 100*(fhr/100))/60.
    end if

    NS  = str_get_cols(lat,-1,-1)
    lat := tofloat(lat)*0.1
    if(any(NS.eq."S"))then
        S = ind(NS.eq."S")
        lat(S) = -1. * lat(S)
    end if

    EW  = str_get_cols(lon,-1,-1)
    lon := tofloat(lon)*0.1
    if(any(EW.eq."W"))then
        W = ind(EW.eq."W")
        lon(W) = -1. * lon(W)
    end if

    data = True
    data@basin = basin
    data@fhr = fhr

    data@init = init
    data@timeunits = init@units
    data@valid = data@init + data@fhr
    data@lat = lat
    data@lon = lon
    if(all(isvar((/"heading","speed"/))))then
        data@speed = speed
        data@heading = heading
    else
        res := True
        res@debug = False
        res@plus_minus_hrs = 6
        data = spdhed(lat,lon,data,res)
    end if
    data@mslp = mslp
    data@vmax = vmax
    data@rad = rad
    data@dd = toint(cd_string(init,"%d")) ; initialization day
    data@hh = toint(cd_string(init,"%h")) ; initialization hour
    if(isvar("stormname"))then
        data@stormname = stormname(maxind(vmax))
    else
        data@stormname = ""
    end if
        
    return(data)
end
undef("read_wrf_track")
function read_wrf_track(filename:string, ininit:numeric, dt:numeric)
begin
    
  ; Read lat/lon speed and pressure
    wrfdata = readAsciiTable(filename,9,"float",0)
    ; stride to skip times (e.g. stride=8 to do every day when times are 3-hrly)
    stride = 1
    wrfdata := wrfdata(::stride,:)
    wrfdata = where(wrfdata.eq.-1,wrfdata@_FillValue,wrfdata)
    data = True
    data@lat = wrfdata(:,0)
    data@lon = wrfdata(:,1)
    itime = wrfdata(:,4)
    data@mslp = wrfdata(:,5)
    data@vmax = wrfdata(:,6) * 1.94384
    n = dimsizes(itime)

    data@basin = new(n,"string")
    data@lev = new(n,"string")
    rad = new(n,"float")
    rad = 34
    data@rad = rad
    data@dd = new(n,"integer")
    data@hh = new(n,"integer")

    fhr := itime * dt
    data@fhr = fhr
    init = new(n,typeof(ininit))
    init = ininit
    data@init = init
    data@valid = data@init + data@fhr

    res := True
    res@plus_minus_hrs = 6
    data = spdhed(data@lat,data@lon,data,res)
    return(data)
end
