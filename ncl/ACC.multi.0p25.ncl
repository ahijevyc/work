; ACC.ncl
; Copied from ACC.multi.ncl Jan 2026
; Tried to adapt to Ivette's DA run and Craig's climo
; Still doesn't work.
;==========================================================================
; Compute Anomaly Correlation Coefficient (ACC) as the _centered_ correlation
; between forecast and analysis (or observed) anomalies.
; 
; For a certain foreacast lead time,
; 
; Input files: xa (Analysis)      
;              xf (Forecast)      
;               C (Climatology)   e.g. hgt.4Xday.1959-1988.ltm.nc
;            => xc at the same time and space as in xa and xf
; 
;     fp = xf - xc at each mpas grid point m
;     ap = xa - xc at each mpas grid point m
;     fave = mean(fp) as area-weighted forecast anomaly mean
;     aave = mean(ap) as area-weighted analysis anomaly mean
;     fprime = fp - fave
;     aprime = ap - aave
;     fstd = stddev(fprime) as area-weighted standard deviation of forecast anomaly
;     astd = stddev(aprime) as area-weighted standard deviation of analysis anomaly
;
; Output:        area_weighted_sum[(fp - fave)*(ap - aave)]
;          ACC = --------------------------------------------
;                        sum[area] * fstd * astd 
;
; Note: This is the _centered_ correlation, not the _uncentered_ correlation.
; See Wilks book for a description of the difference. Basically, the _centered_
; correlation subtracts the area-weighed anomaly means from the anomalies,
; while the _uncentered_ one does not. Fanglin Yang (NOAA) used _centered_ in
; his web pages. Confusingly, earth2studio (and weather agencies, like ECMWF)
; use the _uncentered_ one, too.
;  
; Soyoung Ha (MMM/NCAR) Sep-1-2016
;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/work/ahijevyc/ncl/cd_inv_string.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
if(.not.isvar("fcsth"))then
  fcsth = 120                   ; forecast time to compute ACC in [hr]
end if

zulu = "00" ; UTC time to compute ACC

; period_of_interest = string array of initialization dates, format yyyymmdd
period_of_interest = (/ "2018041[89]*", "201804[23]*", "2018050*", "2018051[0-4]*" /)
yyyy = str_get_cols(period_of_interest,0,3) ; get year from period of interest

; Experiments and variables
;-------------------------------------------------------------------------
grid    = (/ "0p25" /)
expn    = (/ "ivette_liuz_coldstart_15km2018", "ivette_liuz_3_3dhyb_asrama_asrmhs_atms" /)    ; Experiment names

; Array of variable and filename prefix strings
;                                  xvar    cvar
height_names          = (/      "height",  "Z" /)
temperature_names     = (/ "temperature",  "T" /)
zonal_wind_names      = (/      "uzonal",  "U" /)
meridional_wind_names = (/ "umeridional",  "V" /)

varnames = height_names

p_hPa  = 500.                   ; isobaric level
p_unit = "hPa"                  ; level unit
xvar   = varnames(0) + "_" + sprinti("%3i",toint(p_hPa)) + p_unit 
C_file = "/glade/derecho/scratch/schwartz/MPAS/ERA5_forACC/0000utc/average/mean.nc"
cvar   = varnames(1)                                               

; Region of interest
;-------------------------------------------------------------------------
if(.not.isvar("iregion"))then
  iregion = 0 ; 0-based index
end if

;                 0        1      2        3       4      5      6      7
regions = (/"CONUS",   "NA",  "NH", "Tropics",  "SH", "Globe", "WP", "RTrop"/)    
lat1    = (/  25.,     15.,   20.,    -20.,     -80.,   -90.,  -10.,  -20. /)
lat2    = (/  55.,     75.,   80.,     20.,     -20.,    90.,   50.,   20. /)
lon1    = (/ 235.,    200.,    0.,      0.,       0.,     0.,  100.,    0. /)
lon2    = (/ 285.,    305.,  360.,    360.,     360.,   360.,  210.,  360. /)
region  = regions(iregion)

; Input directories and files
;-------------------------------------------------------------------------
data_dir := "/glade/derecho/scratch/ivette/pandac/v3.0.3/" + expn + "/ExtendedFC_latlon/"
anal_dir  = "/glade/derecho/scratch/ivette/pandac/v3.0.3/ivette_init_15km_era5_remapped/Remapped_to_ERA5/"

; OUTPUT (ACC in a text file and a time series plot)
;--------------------------------------------------------------------------
fout_name = "/glade/work/ahijevyc/ncl/out/ACC." + region + "." + xvar + "." + sprinti("%0.3i",fcsth) + "hfcst." + zulu + "Z." + str_join(grid,".") + "."
if(fileexists(fout_name))then
  print(fout_name+" already exists. Remove it first if you want to run this.")
  exit
end if

fout_asc = fout_name + ".txt"

;--------------------------------------------------------------------------
; Main Logic
;--------------------------------------------------------------------------
print("")
print("ACC.ncl: Computing anomaly correlation coefficient in "+fcsth+" h forecast")
print("         for " + xvar + " in " + str_join(expn, ","))
print("")

; Time period of interest
Fdirs  = systemfunc("ls -d " + str_join(data_dir(0) + period_of_interest + "*" + zulu," "))

; Remove forecasts that go past the last available analysis time
ncycle = dimsizes(Fdirs)
Fdirs := Fdirs(0:ncycle-1-fcsth/24)

ncycle = dimsizes(Fdirs)
cycles = new(ncycle,string)
do icyc = 0, ncycle-1
  cycles(icyc) = systemfunc("basename "+Fdirs(icyc))
end do

nexp  = dimsizes(expn)
acc_m = new((/nexp,ncycle/),double) 

listA = new((/nexp,ncycle/),string)
listF = new((/nexp,ncycle/),string)
initdates = new(dimsizes(listF),string)
tf = new(dimsizes(listF),string) ; valid times

; Read expn files
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
  do iexp = 0, nexp-1
    syear  = str_get_cols(cycles(icyc),0,3)
    smonth = str_get_cols(cycles(icyc),4,5)
    sday   = str_get_cols(cycles(icyc),6,7)
    shour  = str_get_cols(cycles(icyc),8,9)
    validjul = cd_inv_calendar(toint(syear),toint(smonth),toint(sday),toint(shour)+fcsth,0,0,"hours since 1900-01-01 00:00:00",0)
    flist   := data_dir(iexp) + cd_string(validjul, "%Y%N%D%H/latlon_era5_diag.%Y-%N-%D_%H.%M.%S.nc")
    
    if(.not.isfilepresent(flist))
      print("Cannot find forecast file: "+flist)
      exit
    end if

    listA(iexp,icyc)     = anal_dir + cycles(icyc) + "/latlon_era5_init." + syear + "-" + smonth + "-" + sday + "_" + shour + ".00.00.nc"
    listF(iexp,icyc)     = data_dir(iexp) + cycles(icyc) + "/" + systemfunc("basename "+flist)
    idate                = str_index_of_substr(listF(iexp,icyc), "/20", -1)
    initdates(iexp,icyc) = str_get_cols(listF(iexp,icyc), idate+1, idate+10)
  end do
end do

; Read Climate Data
;--------------------------------------------------------------------------
fc   = addfile(C_file,"r")
clon = fc->longitude
clat = fc->latitude
clev = fc->level
xclm = fc->$cvar$
if(cvar.eq."Z")then
  xclm = xclm / 9.81
  xclm@units = "m"
  xclm@long_name = "geopotential height"
end if

ck = default_fillvalue("integer")
if(clev@units.eq.p_unit.or.(isatt(clev,"GRIB_name").and.clev@GRIB_name.eq.p_unit)) then
  ck = ind(clev.eq.p_hPa)
end if

; Match Time
;--------------------------------------------------------------------------
idxF = new(ncycle,integer)

; Compute ACC for expn
;--------------------------------------------------------------------------
do iexp = 0, nexp-1
  ; count substrings separated by slashes
  nfields = str_fields_count(listA(iexp,:), "/")
  if (any(nfields.ne.nfields(0)))
    print(nfields)
    print("not all same")
    exit
  end if
  ; get substrings separated by slashes
  time_str = str_get_field(listA(iexp,:), nfields(0), "/")
  time_str = str_sub_str(str_get_field(time_str, 2, "."), "_", " ") + ":" + str_get_field(time_str, 3, ".") + ":" + str_get_field(time_str, 4, ".")
  yy = toint(str_get_cols(time_str, 0, 3))
  mm = toint(str_get_cols(time_str, 5, 6))
  dd = toint(str_get_cols(time_str, 8, 9))
  hh = toint(str_get_cols(time_str, 11, 12))
  mn = toint(str_get_cols(time_str, 14, 15))
  ss = toint(str_get_cols(time_str, 17, 18))
  units = "hours since " + time_str(0)
  new_time := cd_inv_calendar(yy, mm, dd, hh, mn, ss, units, 0)
  new_time!0 = "time"
  valid_time = cd_inv_calendar(yy, mm, dd, hh+fcsth, mn, ss, "hours since 1900-01-01 00:00:00", 0)
  tf(iexp, :) = cd_calendar(valid_time, 3) ; 3 is YYYYMMDDHH format

  fa = addfiles(listA(iexp,:), "r")
  ff = addfiles(listF(iexp,:), "r")

  do icyc = 0, ncycle-1
    ; Now using the date extracted from the filename
    date_wo_year = str_get_cols(time_str(icyc), 5, 12)
    date_wo_year = str_sub_str(date_wo_year, " ", "_")
    idxF(icyc)   = (/ 0 /)
  end do

  ; --- Data Extraction ---
  if(isfilevar(ff[0], xvar)) then
    xa := fa[:]->$xvar$
    xf := ff[:]->$xvar$
  else
    field := str_split(xvar,"_")
    xv    := field(0) + "_diag"
    pa    := fa[0]->pressure_diag
    ik    := ind(pa.eq.p_hPa)
    xa    := fa[:]->$xv$(:,:,ik)
    xf    := ff[:]->$xv$(:,:,ik)
  end if

  ; Overwrite the coordinate variable with our derived one
  xa!0 = "time"
  xa&time = new_time

  xm := xclm(idxF,ck,:,:)
  xc = linint2_Wrap(clon, clat(::-1), xm(:,::-1,:), True, xa&lon, xa&lat, 0)
  Aanom = xa - xc
  Fanom = xf - xc
  copy_VarCoords(xa, Aanom)
  copy_VarCoords(xf, Fanom)

  ; Slice to region and reassign (using () for NCL subscripting)
  ap := Aanom(:,{lat1(iregion):lat2(iregion)},{lon1(iregion):lon2(iregion)})
  fp := Fanom(:,{lat1(iregion):lat2(iregion)},{lon1(iregion):lon2(iregion)})

  ; Ensure weights match the sliced latitude dimension
  wgty = cos(ap&lat * get_d2r("double"))
  wgty@long_name = "cosine latitude for area weighting"

  aave := wgt_areaave_Wrap(ap, wgty, 1.0, 1)
  fave := wgt_areaave_Wrap(fp, wgty, 1.0, 1)
  ;print("Area-weighted mean: "+aave+" "+fave)

  do icyc = 0, ncycle-1
    aprime := ap(icyc,:,:) - aave(icyc)
    fprime := fp(icyc,:,:) - fave(icyc)
    
    ; Use the sub-weighted array here too
    astd := sqrt(wgt_areaave(aprime^2, wgty, 1.0, 1))
    fstd := sqrt(wgt_areaave(fprime^2, wgty, 1.0, 1))
    
    acc_m(iexp,icyc) = wgt_areaave(fprime*aprime, wgty, 1.0, 1) / (fstd*astd)
  end do
end do

; Output and Final Combine
;--------------------------------------------------------------------------
acc_all = acc_m

print("writing "+fout_asc)
write_table(fout_asc, "w", [/"init_date","valid_date","lat1","lat2","lon1","lon2",str_join(expn," ")/], "%s %s %s %s %s %s %s")

do icyc=0,ncycle-1
  write_table(fout_asc,"a",[/initdates(0,icyc),tf(0,icyc),lat1(iregion),lat2(iregion),lon1(iregion),lon2(iregion),str_join(tostring(acc_all(:,icyc))," ")/], "%s %s %f %f %f %f %s")
end do
