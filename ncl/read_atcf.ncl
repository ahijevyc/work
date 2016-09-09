undef("spdhed")

; function spdhed (speed and heading)
; Input:
; 	3 scalars or arrays of 
; 	lat, lon, and time in hours
; 
; Returns:
; 	data variable with attributes 
;	speed, heading, U, and V.
;	These are same size as input.
;
function spdhed(lat,lon,hours)
begin
    n = dimsizes(lat)
    if(n.ne.dimsizes(lon).or.n.ne.dimsizes(hours))then
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
    ds(0) = gc_latlon(lat(0),lon(0),lat(1),lon(1),2,3); last arg 3=meters
    dhr(0) = hours(1)-hours(0)
    heading(0) = gc_dangle((/lat(0),lat(0)+1,lat(1)/), (/lon(0),lon(0),lon(1)/))
    ; calculate distance between one point earlier and one point later
    do i=1,n-2 
	ds(i) = gc_latlon(lat(i-1),lon(i-1),lat(i+1),lon(i+1),2,3); last arg 3=meters
        heading(i) = gc_dangle((/lat(i-1),lat(i-1)+1,lat(i+1)/), (/lon(i-1),lon(i-1),lon(i+1)/))
	dhr(i) = hours(i+1)-hours(i-1)
    end do
    ds(n-1) = gc_latlon(lat(i-1),lon(i-1),lat(i),lon(i),2,3); last arg 3=meters
    heading(n-1) = gc_dangle((/lat(n-2),lat(n-2)+1,lat(n-1)/), (/lon(n-2),lon(n-2),lon(n-1)/))
    dhr(n-1) = hours(n-1)-hours(n-2)
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
    return(data)
end

undef("read_atcf")
function read_atcf(filename:string)
begin
	
  ; Read lat/lon speed and pressure
    basin := systemfunc("cut -f1 -d, " + filename)

    ; Count number of columns to guess how to read it
    ncols = systemfunc("head -n 1 " + filename+" | wc -w")
    if(ncols.eq.31)then ; fort.66 style
	    ; Read Time stamps
	    yyyymmddhh_init = systemfunc("cut -c9-18 " + filename)
	    ; Fixed from 31-34
    	    print("read_atcf.ncl: this needs to be fixed. columns, fields, everything. . . ")
	    fhr := stringtofloat(systemfunc("cut -c31-33 " + filename))
	    lat := stringtofloat(systemfunc("cut -c36-38 " + filename))
	    lon := stringtofloat(systemfunc("cut -c42-45 " + filename))
	    EW  = (systemfunc("cut -c46 " + filename))
	    exit
	    vmax = stringtofloat(systemfunc("cut -c49-51 " + filename))
	    mslp = stringtofloat(systemfunc("cut -c54-57 " + filename))
	    rad := stringtofloat(systemfunc("cut -c65-66 " + filename))
    end if
    if(ncols.eq.20)then ; fort.69 style
	    ; Read Time stamps
	    yyyymmddhh_init = str_left_strip(systemfunc("cut -f3 -d, " + filename)) ; first character is space
	    ; Fixed from 31-34
	    fhr := stringtofloat(systemfunc("cut -f6 -d, " + filename))
     	    if(max(fhr).gt.480)then
		; if fhr exceeds 480 assume it is of form hhhmm.
		fhr=fhr/100 + (fhr - 100*(fhr/100))/60.
	    end if
	    lat := systemfunc("cut -f7 -d, " + filename)
	    lon := systemfunc("cut -f8 -d, " + filename)
	    vmax = stringtofloat(systemfunc("cut -f9 -d, " + filename)) 
	    mslp = stringtofloat(systemfunc("cut -f10 -d, " + filename))
	    rad := stringtofloat(systemfunc("cut -f12 -d, " + filename))
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
