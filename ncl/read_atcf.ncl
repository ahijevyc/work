undef("spdhed")

; function spdhed (speed and heading)
; Input:
; 	3 scalars or arrays of 
; 	lat, lon, and time in hours
; 
; Returns:
; 	data variable with attributes 
;	speed, heading, U, and V.
;	speed is calculated between one point earlier and one point later.
;	These are same size as input.
;
function spdhed(inlat,inlon,inhours)
begin
    debug = False

    ; Make copies of input variables.

    lat = inlat
    lon = inlon
    hours = inhours

    plusminust = 6 ; plus and minus time interval for velocity calculation.
		; returned as data@spdhed_plusminust attribute
 
    ; ATCF sometimes has 0-kt, 34-kt, 50-kt, and 64-kt lines all for the same time.
    ; I want to allow for repeated lines for the same time in the calculations below. 

    n = dimsizes(lat)
    ; Sanity check. Make sure input arrays are all the same size.
    if(any(n.ne.dimsizes(lon)).or.any(n.ne.dimsizes(hours)))then
	print("read_atcf/spdhed: lat, lon, and hours must be same size")
	printVarSummary(lat)
	printVarSummary(lon)
	printVarSummary(hours)
    end if
    ds = new(n,double)
    dhr = new(n,double)
    heading = new(n,float)
    speed = new(n,double)
    speed@units = "m/s"

    iplust = ind( hours-hours(0) .eq. plusminust)
    if(any(ismissing(iplust)))then
        print("could not get index where time is "+plusminust+" hours later than first time.")
	exit
    end if
    iplust := iplust(0)

    iminst0 = ind( hours-hours(n-1) .eq. -plusminust)
    if(any(ismissing(iminst0)))then
        print("could not get index where time is "+plusminust+" hours earlier than last time.")
	exit
    end if
    iminst0 := max(iminst0)

    ; Fill in speed and heading of first time using first time and second time. 
    ds(0:iplust-1) = gc_latlon(lat(0),lon(0),lat(iplust),lon(iplust),2,3); last arg 3=meters
    dhr(0:iplust-1) = hours(iplust)-hours(0)
    ; Return the angle between a unit vector pointing due north from point A and a
    ; great circle from point A and ending at point C.
    ; Returned angle is positive if C is west of A and negative if C is east of A.
    ; That is the opposite of meteorological heading so we multiply by -1 below.
    heading(0:iplust-1) = gc_dangle((/lat(0),lat(0)+1,lat(iplust)/), (/lon(0),lon(0),lon(iplust)/))
    if(debug.or.dhr(0).ne.plusminust)then
        print(lat)
	print(lon)
	print(hours)
	print(iminst0)
	print(iplust)
    end if
    ; Loop through middle times 
    ; calculate speed/heading between earlier and later times (by plusminust)
    do i=iplust,iminst0 
    	iminst := ind( hours-hours(i) .eq. -plusminust)
    	iplust := ind( hours-hours(i) .eq.  plusminust)
	if(any(ismissing(iminst)).or.any(ismissing(iplust)))then
	        print("could not get indices where time is +/-"+plusminust+" hours from " + hours(i))
		print(i)
		print(iminst)
		print(iplust)
		exit
	end if
	iminst := iminst(0)
	iplust := iplust(0)

	ds(i) = gc_latlon(lat(iminst),lon(iminst),lat(iplust),lon(iplust),2,3); last arg 3=meters
        heading(i) = gc_dangle((/lat(iminst),lat(iminst)+1,lat(iplust)/), (/lon(iminst),lon(iminst),lon(iplust)/))
	dhr(i) = hours(iplust)-hours(iminst)
    end do
    ; fill in last time with speed and heading between 2nd-to-last time and last time.
    ; pick up with index i. It is the first line of the last time.
    ; i-i is the index of the 2nd-to-last time.
    ds(i:) = gc_latlon(lat(i-1),lon(i-1),lat(i),lon(i),2,3); last arg 3=meters
    heading(i:) = gc_dangle((/lat(i-1),lat(i-1)+1,lat(i)/), (/lon(i-1),lon(i-1),lon(i)/))
    dhr(i:) = hours(i)-hours(i-1)
    if(debug)then
        ff = 6
        print("first "+ff+" ds,dhr,heading=")
        print(ds(:ff)+","+dhr(:ff)+","+heading(:ff))
        print("last few ds,dhr,heading=")
        print(ds(i-ff:)+","+dhr(i-ff:)+","+heading(i-ff:))
    end if
    heading = mod(-heading + 360,360)
    i := ind(dhr.ne.0)
    speed(i) = ds(i)/dhr(i)/3600.
    data = True
    data@speed = speed
    data@heading = heading
    ; heading is opposite of wind direction
    tmp = wind_component(speed, heading+180., 0)
    data@U = tmp(0,:)
    data@V = tmp(1,:)
    data@spdhed_plusminust = plusminust
    return(data)
end

undef("read_atcf")
function read_atcf(filename:string)
; Define local variables. We do not want these to be accessible outside the scope of the function.
local fhr, lat, lon, vmax, mslp, rad
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
    if(ncols.eq.31)then ; fort.66 style
	    ; Read Time stamps
	    yyyymmddhh_init = str_left_strip(systemfunc("cut -f4 -d, " + filename)) ; first character is space
	    fhr = stringtofloat(systemfunc("cut -f7 -d, " + filename))
	    lat = systemfunc("cut -f8 -d, " + filename)
	    lon = systemfunc("cut -f9 -d, " + filename)
	    vmax = stringtofloat(systemfunc("cut -f10 -d, " + filename)) 
	    mslp = stringtofloat(systemfunc("cut -f11 -d, " + filename))
	    rad = stringtofloat(systemfunc("cut -f13 -d, " + filename))
    end if
    if(ncols.eq.17.or.ncols.eq.20.or.ncols.eq.22.or.ncols.eq.29.or.ncols.eq.37.or.ncols.eq.41.or.ncols.eq.45)then ; fort.69 style
	    ; Read Time stamps
	    yyyymmddhh_init = str_left_strip(systemfunc("cut -f3 -d, " + filename)) ; first character is space
	    fhr = stringtofloat(systemfunc("cut -f6 -d, " + filename))
	    lat = systemfunc("cut -f7 -d, " + filename)
	    lon = systemfunc("cut -f8 -d, " + filename)
	    vmax = stringtofloat(systemfunc("cut -f9 -d, " + filename)) 
	    mslp = stringtofloat(systemfunc("cut -f10 -d, " + filename))
	    rad = stringtofloat(systemfunc("cut -f12 -d, " + filename))
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
    if(max(fhr).gt.480)then
	; if fhr exceeds 480 assume it is of form hhhmm.
	fhr=fhr/100 + (fhr - 100*(fhr/100))/60.
    end if
    yyyy = toint(str_get_cols(yyyymmddhh_init,0,3))
    month = toint(str_get_cols(yyyymmddhh_init, 4,5))
    dd = toint(str_get_cols(yyyymmddhh_init, 6,7))
    hh = toint(str_get_cols(yyyymmddhh_init, 8,9))
    mn = new(dimsizes(hh),"integer")
    mn = 0
    sc = new(dimsizes(hh),"integer") 
    sc = 0

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
    init = cd_inv_calendar(yyyy,month,dd,hh,mn,sc,"hour since 1970-01-01 00:00:00", 0)
    data@init = init
    data@timeunits = init@units
    data@valid = data@init + data@fhr
    data@lat = lat
    data@lon = lon
    data = spdhed(lat,lon,data@valid)
    data@mslp = mslp
    data@vmax = vmax
    data@rad = rad
    data@dd = dd
    data@hh = hh
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

    data = spdhed(data@lat,data@lon,data@valid)
    return(data)
end
