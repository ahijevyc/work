;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;track.ncl
;
;Written by Abby Jaye, MMM/NCAR (2017)
;   jaye@ucar.edu
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;To run the script, type:
;
;     ncl track.ncl
;
;You will be prompted to enter the location of your data and the I,J that are
;  closest to the storm center
;
;OUTPUTS:
;
;  Time: Output time period 
;  I: I grid cell of storm center
;  J: J grid cell of storm center
;  Lon: Longitude of storm center
;  Lat: Latitude of storm center
;  LU: Land use category. 17=water
;  U10: U wind at 10m at storm center (m/s)
;  V10: V wind at 10m at storm center (m/s)
;  MaxWnd: Max wind speed of storm (m/s)
;  SLP: Sea Level Pressure at storm center (mb)
;  RMAX: Radius of maximum wind (km)
;  R34: Radius of maximum wind (34kts) (km)
;  R50: Radius of maximum wind (50kts) (km)
;  R56: Radius of maximum wind (56kts) (km)
;  R64: Radius of maximum wind (64kts) (km)
;  R100: Radius of maximum wind (100kts) (km)
;  R34_SW: R34 for the SW quadrant of the storm (km)
;  R34_SE: R34 for the SE quadrant of the storm (km)
;  R34_NW: R34 for the NW quadrant of the storm (km)
;  R34_NE: R34 for the NE quadrant of the storm (km)
;  R50_SW: R50 for the SW quadrant of the storm (km)
;  R50_SE: R50 for the SE quadrant of the storm (km)
;  R50_NW: R50 for the NW quadrant of the storm (km)
;  R50_NE: R50 for the NE quadrant of the storm (km)
;  R56_SW: R56 for the SW quadrant of the storm (km)
;  R56_SE: R56 for the SE quadrant of the storm (km)
;  R56_NW: R56 for the NW quadrant of the storm (km)
;  R56_NE: R56 for the NE quadrant of the storm (km)
;  R64_SW: R64 for the SW quadrant of the storm (km)
;  R64_SE: R64 for the SE quadrant of the storm (km)
;  R64_NW: R64 for the NW quadrant of the storm (km)
;  R64_NE: R64 for the NE quadrant of the storm (km)
;  R100_SW: R100 for the SW quadrant of the storm (km)
;  R100_SE: R100 for the SE quadrant of the storm (km)
;  R100_NW: R100 for the NW quadrant of the storm (km)
;  R100_NE: R100 for the NE quadrant of the storm (km)
;  VT: Translation speed (m/s)
;  CDP: Cyclone Damage Potential Index (Holland and Done)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"
undef("minslp_in_box")
procedure minslp_in_box(slp:float,wndspd:float,max_wnd_spd:float, \
                        box:integer,it:integer,i:integer,j:integer,  \
                        minslp_i:integer,minslp_j:integer,        \
                        ny:integer,nx:integer)
local indices, slp_surr, wind_surr
begin

; "box" grid points = 200km.
; we want a square that is "box" grid points on each side of the i and j
; that comes in.  The i and j points that come in are where the previous
; minimum sea level pressure in the grid was.  Since we are tracking
; a storm we only want the minimum sea level pressure 
; that is associated with the storm.
  
   start_j = j - box
   end_j   = j + box
   if(start_j .lt. 0) then
      start_j = 0
   end if

   if(end_j .gt. ny) then
      end_j = ny
   end if
   
   start_i = i - box
   end_i   = i + box

   if(start_i .lt. 0) then
      start_i = 0
   end if

   if(end_i .gt. nx) then
      end_i = nx
   end if
   
   slp_surr = slp(it,start_j:end_j,start_i:end_i)
   wnd_spd_surr = wndspd(it,start_j:end_j,start_i:end_i)

   ; Find indices of minslp
   indices = ind_resolve(minind(ndtooned(slp_surr)),dimsizes(slp_surr))
   minslp_j = indices(0,0)+start_j
   minslp_i = indices(0,1)+start_i

   max_wnd_spd = max(wnd_spd_surr)
end ;minslp_in_box

;-------------------------------------------------------------------------

undef("r34_r100")

function r34_r100(dx, spd_2d:numeric)

local missing_r, dx, spd_2d, v_1d, r_2d, ii_c, jj_c, dims

begin
  missing_r = -999.
  n_dir = 8
  v_1d = (/17.4911, 25.7222, 28.80886, 32.92442, 51.4444/) ; calc r34,r50,r56,r64,r100

  n_r = dimsizes(v_1d)
  r_2d = new((/n_r, n_dir/), float)
  r_2d@_FillValue = missing_r
  final = new((n_r+(n_r*4)),float)
  final@_FillValue = missing_r

  dims  = dimsizes(spd_2d)
  j_max = dims(0)
  i_max = dims(1)
  jj_c  = j_max/2
  ii_c  = i_max/2
  n_adj = 2

  spddiag = new(ii_c+1,float)

  ; S
  do nr = 0, n_r - 1
    cells := ind(spd_2d(0:jj_c:-1,ii_c).ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,0) = dx*cells(i)
      else
        break
      end if
    end do

  ; N
    cells := ind(spd_2d(jj_c:j_max-1,ii_c).ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,1) = dx*cells(i)
      else
        break
      end if
    end do

  ; W
    cells := ind(spd_2d(jj_c,0:ii_c:-1).ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,2) = dx*cells(i)
      else
        break
      end if
    end do

  ; E
    cells := ind(spd_2d(jj_c,ii_c:i_max-1).ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,3) = dx*cells(i)
      else
        break
      end if
    end do

  ; SW
    do m=0,jj_c
      spddiag(m) = spd_2d(m,m)
    end do
    cells := ind(spddiag(::-1).ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,4) = sqrt(2)*(dx*cells(i))
      else
        break
      end if
    end do

  ; SE
    m = 0
    do n=jj_c,j_max-1
      spddiag(m) = spd_2d(n,jj_c-m)
      m = m+1
    end do
    cells := ind(spddiag.ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,5) = sqrt(2)*(dx*cells(i))
      else
        break
      end if
    end do

  ; NW
    m = 0
    do n=jj_c,j_max-1
      spddiag(m) = spd_2d(jj_c-m,n)
      m = m+1
    end do
    cells := ind(spddiag.ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,6) = sqrt(2)*(dx*cells(i))
      else
        break
      end if
    end do

  ; NE
    m = 0
    do n=jj_c,j_max-1
      spddiag(m) = spd_2d(n,n)
      m = m+1
    end do
    cells := ind(spddiag.ge.v_1d(nr))
    dimCELL := dimsizes(cells)
    do i=1,dimCELL-1
      if(cells(i).eq.cells(i-1)+1) then
        r_2d(nr,7) = sqrt(2)*(dx*cells(i))
      else
        break
      end if
    end do

  end do        ; end of nr-loop

  final(0:4) = dim_avg_n(r_2d,1)

  ; Calculate r34,r50,r56,r64,r100 over quadrants (weighted to diagonal)
  final(5) = (r_2d(0,0)+r_2d(0,2)+(2*r_2d(0,4)))/4. ;r34sw
  final(6) = (r_2d(0,0)+r_2d(0,3)+(2*r_2d(0,5)))/4. ;r34se
  final(7) = (r_2d(0,1)+r_2d(0,2)+(2*r_2d(0,6)))/4. ;r34nw
  final(8) = (r_2d(0,1)+r_2d(0,3)+(2*r_2d(0,7)))/4. ;r34ne
  final(9) = (r_2d(1,0)+r_2d(1,2)+(2*r_2d(1,4)))/4. ;r50sw
  final(10) = (r_2d(1,0)+r_2d(1,3)+(2*r_2d(1,5)))/4. ;r50se
  final(11) = (r_2d(1,1)+r_2d(1,2)+(2*r_2d(1,6)))/4. ;r50nw
  final(12) = (r_2d(1,1)+r_2d(1,3)+(2*r_2d(1,7)))/4. ;r50ne
  final(13) = (r_2d(2,0)+r_2d(2,2)+(2*r_2d(2,4)))/4. ;r56sw
  final(14) = (r_2d(2,0)+r_2d(2,3)+(2*r_2d(2,5)))/4. ;r56se
  final(15) = (r_2d(2,1)+r_2d(2,2)+(2*r_2d(2,6)))/4. ;r56nw
  final(16) = (r_2d(2,1)+r_2d(2,3)+(2*r_2d(2,7)))/4. ;r56ne
  final(17) = (r_2d(3,0)+r_2d(3,2)+(2*r_2d(3,4)))/4. ;r64sw
  final(18) = (r_2d(3,0)+r_2d(3,3)+(2*r_2d(3,5)))/4. ;r64se
  final(19) = (r_2d(3,1)+r_2d(3,2)+(2*r_2d(3,6)))/4. ;r64nw
  final(20) = (r_2d(3,1)+r_2d(3,3)+(2*r_2d(3,7)))/4. ;r64ne
  final(21) = (r_2d(4,0)+r_2d(4,2)+(2*r_2d(4,4)))/4. ;r100sw
  final(22) = (r_2d(4,0)+r_2d(4,3)+(2*r_2d(4,5)))/4. ;r100se
  final(23) = (r_2d(4,1)+r_2d(4,2)+(2*r_2d(4,6)))/4. ;r100nw
  final(24) = (r_2d(4,1)+r_2d(4,3)+(2*r_2d(4,7)))/4. ;r100ne

  return(final)

end ;r34_r100

;-------------------------------------------------------------------------

; Calculate translation speed and direction of TC
undef ("vt_tc")

function vt_tc (lat:numeric, lon:numeric, hh:numeric)

local dt0, dt1, ds, lon_tc, r_tmp

begin

  km_nm_2 = 0.539956803*0.5     ; 1 kilometer = 0.539956803 nm, nautical mile = 1.852 km
  dt0 = hh(1) - hh(0)
  if(dt0.le.0) then
     dt0 = 24 + dt0
  end if

  dt1 = hh(2) - hh(1)
  if(dt1.le.0) then
    dt1 = 24 + dt1
  end if

  if(dt0.eq.dt1) then
     ds = gc_latlon(lat(0), lon(0), lat(2), lon(2), 2, 4)
     data_vt = ds*km_nm_2/tofloat(dt0)      ; knot =1nm/hour
     lon_tc = lon(2)-lon(0)
     lon_tc = where(lon_tc.lt.-180, lon_tc+360., lon_tc)
     lon_tc = where(lon_tc.gt.180,  lon_tc-360., lon_tc)
     data_dir = wind_direction(lon_tc, lat(2)-lat(0), 0)
   else if (dt0.lt.dt1) then
     r_tmp   = int2flt(dt0)/int2flt(dt1)
     lat_tmp = lat(1) + (lat(2) - lat(1))*r_tmp
     lon_tmp = lon(1) + (lon(2) - lon(1))*r_tmp
     ds = gc_latlon(lat(0), lon(0), lat_tmp, lon_tmp, 2, 4)
     data_vt  = ds*km_nm_2/int2flt(dt0)      ; knot =1nm/hour
     lon_tc = lon_tmp - lon(0)
     lon_tc = where(lon_tc.lt.-180, lon_tc+360., lon_tc)
     lon_tc = where(lon_tc.gt.180,  lon_tc-360., lon_tc)
     data_dir = wind_direction(lon_tc, lat_tmp-lat(0),0)
   else
     r_tmp   = 1 - int2flt(dt1)/int2flt(dt0)
     lat_tmp = lat(0) + (lat(1) - lat(0))*r_tmp
     lon_tmp = lon(0) + (lon(1) - lon(0))*r_tmp
     ds = gc_latlon(lat_tmp, lon_tmp, lat(2),lon(2), 2, 4)
     data_vt  = ds*km_nm_2/int2flt(dt1)      ; knot =1nm/hour
     lon_tc = lon(2) - lon_tmp
     lon_tc = where(lon_tc.lt.-180, lon_tc+360., lon_tc)
     lon_tc = where(lon_tc.gt.180,  lon_tc-360., lon_tc)
     data_dir = wind_direction(lon_tc, lat(2)-lat_tmp,0)
   end if
   end if

   return(data_vt)
end ;vt_tc

;-------------------------------------------------------------------------
begin

; Prompts for user entry
if(.not.isvar("DATAdir"))then
    print("Enter path and beginning part of files (i.e. /glade/scratch/jaye/run/wrfout*):")
    DATAdir = systemfunc("read DATAdir; echo $DATAdir")
end if
if(.not.isvar("Is"))then
    print("Enter I grid cell location closest to the storm center (i.e. 408):")
    Is = toint(systemfunc("read Is; echo $Is"))
end if
if(.not.isvar("Js"))then
    print("Enter J grid cell location closest to the storm center (i.e. 195):")
    Js = toint(systemfunc("read Js; echo $Js"))
end if

; Hardcode in data directory and i,j grid points
;DATAdir  = "/glade/scratch/jaye/IAG/runs/i408_j195_williswinde10_dfi2hr/SFC*" 
;Is = 408
;Js = 195

FILES = systemfunc (" ls -1 " + DATAdir)
numFILES = dimsizes(FILES)
filelist = addfiles (FILES, "r")         

FValue = -999.

print("Calculating Storm Track....")

if (dimsizes(FILES) .gt. 0 ) then
  a  = addfiles(FILES+".nc","r") 
  times = wrf_user_getvar(a,"times",-1) 
  ntimes = dimsizes(times)         
  Times = wrf_user_getvar(a,"Times",-1) 
  TIMES = wrf_times_c(Times,3)

  LATs = new(ntimes,float,FValue)
  LONs = new(ntimes,float,FValue)
  dfLATs = new(ntimes,float,FValue)
  dfLONs = new(ntimes,float,FValue)
  landsea = new(ntimes,float,FValue)
  X_data = new((/ntimes,38/),float,FValue)

;Get the fields we are interested in
  if(isfilevar(a[0],"AFWA_MSLP")) then
    slp = wrf_user_getvar(a,"AFWA_MSLP",-1)    
  else
    slp = wrf_user_getvar(a,"slp",-1)
    slp = slp*100.
  end if
  LAT = wrf_user_getvar(a,"XLAT",-1)    
  LON = wrf_user_getvar(a,"XLONG",-1)    
  LAND = wrf_user_getvar(a,"LU_INDEX",-1)    
  u10 =  wrf_user_getvar(a,"U10",-1)
  v10 =  wrf_user_getvar(a,"V10",-1)
  slp = slp/100.
  usqrd = u10 * u10
  vsqrd = v10 * v10
  wndspd = sqrt(usqrd + vsqrd)

  thedims = dimsizes(slp)
  ny = thedims(1)
  nx = thedims(2)
  dx = filelist[0]@DX/1000 ; convert m to km
  box_halfwidth = 200. ; km
  box = round(box_halfwidth/dx,3); opt=3: return values of type integer

; Write out data for time 0  
; time=0 held first guess Is and Js, corner lat/lon/landsea, max_wind_spd in box, and slp(0,Js,Is)
; time=0 was not analyzed for R34, R50, R64, R100. But why not?
; Instead of filling time=0 with first guess, do full analysis starting at time=0

; Start loop through each time to calculate variables
  do ii = 0,ntimes-1
; Calculate the maximum wind speed of the storm
    if(ii .eq. 0) then
      prev_i = Is
      prev_j = Js
      minslp_i = -1
      minslp_j = -1
    end if
    max_wnd_spd = 0.0
    i = prev_i
    j = prev_j
    minslp_in_box(slp,wndspd,max_wnd_spd,box,ii,i,j,minslp_i,minslp_j,ny,nx)
    wnd1D := ndtooned(wndspd(ii,:,:))
    dsizes_wnd := dimsizes(wndspd(ii,:,:))
    indices_wnd  := ind_resolve(ind(wnd1D.eq.max_wnd_spd),dsizes_wnd)
    max_j = indices_wnd(0,0)
    max_i = indices_wnd(0,1)
    LATs(ii) = LAT(ii,minslp_j,minslp_i)
    LONs(ii) = LON(ii,minslp_j,minslp_i)
    landsea(ii) = LAND(ii,minslp_j,minslp_i)

; Calculate R34
    missing_r = -999.
    v34_ms = 34.0 * 0.514444
    boxa = 10.
    boxpt = toint((boxa*100.)/dx)           ;This is creating a 10 degree box around the storm
    n_surr = min((/(minslp_j+boxpt),ny-1/)) ;This is finding the minimum of the 10 degree box
    s_surr = max((/(minslp_j-boxpt),0/))    ; or the edge of the domain
    e_surr = min((/(minslp_i+boxpt),nx-1/))
    w_surr = max((/(minslp_i-boxpt),0/))
    delt := new(4,integer)
    if(n_surr.eq.ny-1) then
      delt(0) = (minslp_j+boxpt)-(ny-1)
    end if
    if(s_surr.eq.0) then
      delt(1) = abs(minslp_j-boxpt)
    end if
    if(e_surr.eq.nx-1) then
      delt(2) = (minslp_i+boxpt)-(nx-1)
    end if
    if(w_surr.eq.0) then
      delt(3) = abs(minslp_i-boxpt)
    end if
    maxd := max(delt)
    if(.not.ismissing(maxd)) then
      n_surr = (minslp_j+boxpt)-maxd
      s_surr = (minslp_j-boxpt)+maxd
      e_surr = (minslp_i+boxpt)-maxd
      w_surr = (minslp_i-boxpt)+maxd 
    end if

    u10_surr := u10(ii,s_surr:n_surr,w_surr:e_surr)
    v10_surr := v10(ii,s_surr:n_surr,w_surr:e_surr)
    spd10_surr := u10_surr*u10_surr + v10_surr*v10_surr
    spd10_max = max(spd10_surr)

    ; Get indices of wind speed max
    indices = ind_resolve(maxind(ndtooned(spd10_surr)),dimsizes(spd10_surr))
    j_lat_s = indices(0,0)+s_surr
    i_lon_s = indices(0,1)+w_surr

    rmax_avg = dx*sqrt((j_lat_s-minslp_j)^2+(i_lon_s-minslp_i)^2)
    if(sqrt(spd10_max).ge.v34_ms) then
      X_data(ii,11:35) = (/r34_r100(dx,sqrt(spd10_surr))/)
    else
      X_data(ii,11:35) = (/missing_r/)
    end if

; Write out variables to table
    prev_j = minslp_j
    prev_i = minslp_i
    X_data(ii,0) = (/ii/)
    X_data(ii,1) = (/minslp_i/)
    X_data(ii,2) = (/minslp_j/)
    X_data(ii,3) = (/LONs(ii)/)
    X_data(ii,4) = (/LATs(ii)/)
    X_data(ii,5) = (/landsea(ii)/)
    X_data(ii,6) = (/u10(ii,max_j,max_i)/)
    X_data(ii,7) = (/v10(ii,max_j,max_i)/)
    X_data(ii,8) = (/max_wnd_spd/)
    X_data(ii,9) = (/slp(ii,minslp_j,minslp_i)/)
    X_data(ii,10) = (/rmax_avg/)

  end do

; Calculate CDP
  ms2kt = 1.94
  vm_avg = 39.003   ;vm_avg and r34_avg taken from average of i407_j195_williswinde10_dfi2hr
  r34_avg = 132.416
  vm = X_data(:,8)*ms2kt

  if(.not.all(ismissing(X_data(:,11))).and.any(vm.gt.34.)) then
    vt = vm
    do nt = 1,ntimes-2
      vt(nt) = vt_tc(X_data(nt-1:nt+1,4),X_data(nt-1:nt+1,3),X_data(nt-1:nt+1,0))
    end do
    vt(0) = vt(1)
    vt_cdp = where(vt.lt.5.,5.,vt)
    vt_cdp = where(vt_cdp.gt.15.,15.,vt_cdp)
    vm = where(vm.gt.100.or.vm.lt.34.,-999.,vm)
    r34_cdp = where(X_data(:,11).gt.300.,300.,X_data(:,11))
    cdp = 4*((vm/vm_avg)^3 + 5.*(r34_cdp/r34_avg))/vt_cdp
  else
    continue
  end if
  vt = where(vt.gt.100,-999.,vt)
  X_data(:,36) = vt
  X_data(:,37) = cdp

; Write out output file
  opt = True
  opt@title = "   Time      I        J       Lon       Lat      LU       U10      V10     MaxWnd    SLP     RMAX     R34       R50     R56       R64     R100    R34_SW   R34_SE   R34_NW   R34_NE   R50_SW   R50_SE   R50_NW   R50_NE   R56_SW   R56_SE   R56_NW   R56_NE   R64_SW   R64_SE   R64_NW   R64_NE   R100_SW  R100_SE  R100_NW  R100_NE    VT      CDP"
  opt@fout = "track_out.txt"
  fmt = "38f9.2"
  write_matrix (X_data, fmt, opt)
  print("")
  print("All done! Your file '"+opt@fout+"' is ready!")
  print("Further information on outputs can be found in the header of track.ncl")

end if

do ii=0,ntimes-1
    LATi = round(abs(X_data(ii,4)*10),3)
    LONi = round(abs(X_data(ii,3)*10),3)
    vmaxi = X_data(ii,8)*1.9438444924574   ;converting winds to knots
    vmax_kt = round(vmaxi,3)
    slpi = round(X_data(ii,9),3)
    radii_kt = X_data(ii,10:35)*0.539956804 ;converting all wind radii info from km to nautical mile
    radii_kt@_FillValue = 0
;    print(radii_kt)

    rmaxi = round(radii_kt(0),3)
    R34i = round(radii_kt(1),3)
    R50i = round(radii_kt(2),3)
    R64i = round(radii_kt(4),3)
    R100i = round(radii_kt(5),3)

    R34_SWi = round(radii_kt(6),3)
    R34_SEi = round(radii_kt(7),3)
    R34_NWi = round(radii_kt(8),3)
    R34_NEi = round(radii_kt(9),3)

    R50_SWi = round(radii_kt(10),3)
    R50_SEi = round(radii_kt(11),3)
    R50_NWi = round(radii_kt(12),3)
    R50_NEi = round(radii_kt(13),3)

    R64_SWi = round(radii_kt(18),3)
    R64_SEi = round(radii_kt(19),3)
    R64_NWi = round(radii_kt(20),3)
    R64_NEi = round(radii_kt(21),3)

    R100_SWi = round(radii_kt(22),3)
    R100_SEi = round(radii_kt(23),3)
    R100_NWi = round(radii_kt(24),3)
    R100_NEi = round(radii_kt(25),3)

;  if( .not. ismissing(R34i) ) then

        print("AL, 09, " + TIMES(ii) + ",   , BEST, " + sprinti("%4.0i", ii ) + ","  \
        + sprinti("%4.0i", LATi) + "N," + sprinti("%5.0i", LONi) + "W," + sprinti("%4.0i",vmax_kt) + "," \
        + sprinti("%5.0i", slpi) + ",   ,  34, NEQ," + sprinti("%5.1i", R34_NEi) + "," + sprinti("%5.1i", R34_SEi) + "," \
        + sprinti("%5.1i",R34_SWi) + "," + sprinti("%5.1i", R34_NWi) + ", 1013,     ," + sprinti("%4.1i",rmaxi) + ",    ,   0,   L,   0,    ,   0,   0,      IKE, X,   ,    ,     ,     ,     ,     ")
;  end if

   ;if( .not. ismissing(R50i) .or.  all(ismissing(radii_kt(9:12))) ) then
   if( .not. all(ismissing(radii_kt(9:12))) ) then
        print("AL, 09, " + TIMES(ii) + ",   , BEST, " + sprinti("%4.0i", ii ) + ","  \
        + sprinti("%4.0i", LATi) + "N," + sprinti("%5.0i", LONi) + "W," + sprinti("%4.0i",vmax_kt) + "," \
        + sprinti("%5.0i", slpi) + ",   ,  50, NEQ," + sprinti("%5.1i",R50_NEi) + "," + sprinti("%5.1i", R50_SEi) + "," \
        + sprinti("%5.1i",R50_SWi) + "," + sprinti("%5.1i", R50_NWi) + ", 1013,     ," + sprinti("%4.1i",rmaxi) + ",    ,   0,   L,   0,    ,   0,   0,      IKE, X,   ,    ,     ,     ,     ,     ")
   end if

   if( .not. ismissing(R64i) ) then
        print("AL, 09, " + TIMES(ii) + ",   , BEST, " + sprinti("%4.0i", ii ) + ","  \
        + sprinti("%4.0i", LATi) + "N," + sprinti("%5.0i", LONi) + "W," + sprinti("%4.0i",vmax_kt) + "," \
        + sprinti("%5.0i", slpi) + ",   ,  64, NEQ," + sprinti("%5.1i",R64_NEi) + "," + sprinti("%5.1i", R64_SEi) + "," \
        + sprinti("%5.1i",R64_SWi) + "," + sprinti("%5.1i", R64_NWi) + ", 1013,     ," + sprinti("%4.1i",rmaxi) + ",    ,   0,   L,   0,    ,   0,   0,      IKE, X,   ,    ,     ,     ,     ,     ")
   end if

   if( .not. ismissing(R100i) ) then
        print("AL, 09, " + TIMES(ii) + ",   , BEST, " + sprinti("%4.0i", ii ) + ","  \
        + sprinti("%4.0i", LATi) + "N," + sprinti("%5.0i", LONi) + "W," + sprinti("%4.0i",vmax_kt) + "," \
        + sprinti("%5.0i", slpi) + ",   , 100, NEQ," + sprinti("%5.1i",R100_NEi) + "," + sprinti("%5.1i", R100_SEi) + "," \
        + sprinti("%5.1i",R100_SWi) + "," + sprinti("%5.1i", R100_NWi) + ", 1013,     ," + sprinti("%4.1i",rmaxi) + ",    ,   0,   L,   0,    ,   0,   0,      IKE, X,   ,    ,     ,     ,     ,     ")
   end if

end do

end
