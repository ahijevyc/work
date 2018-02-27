; ACC.ncl
;==========================================================================
; Compute Anomaly Correlation Coefficient (ACC) as the centered correlation
; between forecast and analysis (or observed) anomalies.
; 
; For a certain foreacast lead time,
; 
; Input files: xa (Analysis)     ex) mpas_init.nc
;              xf (Forecast)     ex) mpas_diag.nc
;               C (Climatology)  ex) hgt.4Xday.1959-1988.ltm.nc
;           => xc at the same time and space as in xa and xf
; 
;    fp = xf - xc at each mpas grid point m
;    ap = xa - xc at each mpas grid point m
;    fave = mean(fp) as area-weighted forecast anomaly mean
;    aave = mean(ap) as area-weighted analysis anomaly mean
;    fprime = fp - fave
;    aprime = ap - aave
;    fstd = stddev(fprime) as area-weighted standard deviation of forecast anomaly
;    astd = stddev(aprime) as area-weighted standard deviation of analysis anomaly
;
; Output:        area_weighted_sum[(fp - fave)*(ap - aave)]
;         ACC = --------------------------------------------
;                       sum[area] * fstd * astd 
; 
; Note: The climate data is provided at 1.0 x 1.0 degree resolution,
;       thus projected onto the MPAS unstructured mesh before computing
;       anomaly correlation coefficient here.
;
; Soyoung Ha (MMM/NCAR) Sep-1-2016
;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/read_time_in_gfs_grb.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
  if(.not.isvar("fcsth"))then
     fcsth = 120                  ; forecast time to compute ACC in [hr]
  end if
     zulu = "00"                ; UTC time to compute ACC
;   period_of_interest = (/ "20160[789]*", "201610[01]*", "2016102[0-6]*" /)
; Use tuna:~ahijevyc/bin/date_range to get range of yyyymmdd dates with a stride.
;   period_of_interest := (/"20161102","20161105","20161108","20161111","20161114","20161117","20161120","20161123","20161126","20161202","20161205","20161208","20161211","20161214","20161217","20161220","20161223","20161226","20161229","20170101","20170104","20170107","20170110","20170113","20170116","20170119","20170122","20170125","20170128","20170131","20170203","20170206","20170209","20170212","20170215","20170218","20170221","20170224","20170227","20170302","20170305","20170308","20170311","20170314","20170317","20170320","20170323","20170326","20170329","20170401","20170404","20170407","20170410","20170413","20170416","20170419","20170422","20170425","20170428","20170501" /)
;   period_of_interest := (/"20161102","20161105","20161108","20161111","20161114","20161117","20161120","20161123","20161126","20161202","20161205","20161208","20161211","20161214","20161217","20161220","20161223","20161226","20161229","20170101","20170104","20170107","20170110","20170113","20170116","20170119","20170122","20170125","20170128","20170131","20170203","20170206","20170209","20170212","20170215","20170218","20170221","20170224","20170227","20170302","20170305","20170308","20170311","20170314","20170317","20170320","20170323","20170326","20170329","20170401","20170404","20170407","20170410","20170413","20170416","20170419","20170422","20170425","20170428" /) ; no may 1 forecast
;   period_of_interest := (/"20161202","20161205","20161208","20161211","20161214","20161217","20161220","20161223","20161226","20161229","20170101","20170104","20170107","20170110","20170113","20170116","20170119","20170122","20170125","20170128","20170131","20170203","20170206","20170209","20170212","20170215","20170218","20170221","20170224","20170227"/)
; period_of_interest := (/"20170101","20170104","20170107","20170110","20170113","20170116","20170119","20170122","20170125","20170128","20170131"/)
;   period_of_interest := (/ "2017032[789]*","2017033*","201704*", "201705*" /)
;     period_of_interest := (/ "20170[789]*", "201710[01]*", "2017102[0-6]*" /)
     period_of_interest := (/ "20171[12]*", "201801*", "20180201*" /)
     yyyy = str_get_cols(period_of_interest,0,3) ; get year from period of interest

 ; Experiments and variables
 ;-------------------------------------------------------------------------
     grid = (/ "uni", "gfs.0p25"       /)
     expn = (/ "MPAS", "GFS"   /)    ; Experiment names (GFS should be listed as the last one). Perhaps change fout_name too.
     cols = (/ "blue", "black"          /)    ; line colors in the plot
  sub_dir = ""                      ; "warm" from EnKF analyses, "cold" from FNL analyses

     xvar = "height_500hPa"            ; field name in mpas
     gvar = "HGT_P0_L100_GLL0"             ; field name in OTHER
     cvar = "HGT_3_ISBL_S51"                ; field name in climate data
                        ;("hgt" for 1981-2010; "HGT_3_ISBL_S51" for 1959-1988)
    p_hPa = 500.                ; isobaric level
   p_unit = "hPa"                ; level unit

 ; Region of interest
 ;-------------------------------------------------------------------------
  if(.not.isvar("iregion"))then
      iregion =   0                 ; 0-based index
  end if
;                0       1     2        3      4     5      6
  regions = (/"CONUS", "NA", "NH","Tropics", "SH","Globe","WP"/)    
     lat1 = (/  25.,    15.,  20.,   -20.,   -80., -90.,  -10. /)
     lat2 = (/  55.,    75.,  80.,    20.,   -20.,  90.,   50. /)
     lon1 = (/ 235.,   200.,   0.,     0.,     0.,   0.,  100. /)
     lon2 = (/ 285.,   305., 360.,   360.,   360., 360.,  210. /)
   region = regions(iregion)

 ; Input directories and files
 ;-------------------------------------------------------------------------
  data_dir := (/ "/glade/scratch/mpasrt/uni/" /)
  anal_dir = data_dir
  gfsa_dir = "/glade/p/rda/data/ds084.1/"
  gfsf_dir = "/glade/p/rda/data/ds084.1/"
  clim_dir = "/glade/p/mmm/syha/ACC/"

 ; OTHER forecast files
   cmd = "ls " + str_join(gfsf_dir + yyyy + "/" +period_of_interest+"/gfs.0p25.*"+zulu+".f"+sprinti("%0.3i",fcsth)+".grib2"," ")
   print(cmd)
   listGF = systemfunc(cmd)
   print(listGF)

 ; Input file names
 ;--------------------------------------------------------------------------
   ; fmap = "/glade/p/work/ahijevyc/mpas_plots/"+grid(0)+"/init.nc"   ; mpas grid info
   ; Instead of looking for init.nc in my work directory (/glade/p/work/ahijevyc/mpas_plots),
   ; go directly to the diagnostic file locations.
   initncs  = systemfunc("ls " + str_join(data_dir(0) + period_of_interest + "*" + zulu," ")+"/init.nc")
   fmap = initncs(0); assume first one is the same as the others.
   ;F_file = grid + ".diag"                   ; mpas forecast
   F_file = "diag"                   ; mpas forecast
   C_file = clim_dir + "hgt.4Xday.1959-1988.ltm.nc"        ; climate data

 ; OUTPUT (ACC in a text file and a time series plot)
 ;--------------------------------------------------------------------------
    ; if you change this (add a suffix like ".ECMWF") you may want to change expn too (used as column headings)
   fout_name = "/glade/p/work/ahijevyc/ncl/out/ACC." + region + "." + xvar + "." + sprinti("%0.3i",fcsth) + "hfcst." + zulu + "Z." + str_join(grid,".") + "." + sub_dir 
   if(fileexists(fout_name))then
        print(fout_name+" already exists. Remove it first if you want to run this.")
        exit
   end if
   fout_asc = fout_name + ".txt"
   if_plot = True    ; Plot ACC in time series? True or False
      ffmt = "png"    ; figure format
      ffig = fout_name
;--------------------------------------------------------------------------
; End user defined parameters
;--------------------------------------------------------------------------

print("")
print("ACC.ncl: Computing anomaly correlation coefficient in MPAS "+fcsth+" h forecast")
print("         for " + xvar + " in " + str_join(expn, ","))
print("")

; Time period of interest - based on the first experiment
;--------------------------------------------------------------------------
; MPAS forecast directories
;Fdirs  = systemfunc("ls -d " + data_dir(0) + yyyy + "*" + zulu )
Fdirs  = systemfunc("ls -d " + str_join(data_dir(0) + period_of_interest + "*" + zulu," "))
ncycle = dimsizes(Fdirs)     ; sample cycle
cycles = new(ncycle,string)
do icyc = 0, ncycle-1
   cycles(icyc) = systemfunc("basename "+Fdirs(icyc))
end do
print("")
print("Processing " + ncycle + " cycles...")
print(cycles+"")
print("")

  nexp = dimsizes(expn)
 acc_m = new((/nexp-1,ncycle/),float)    ; Anomaly Correlation Coefficient (ACC)

; List of files
 listA = new((/nexp-1,ncycle/),string)
 listF = new((/nexp-1,ncycle/),string)
  ngfs = dimsizes(listGF)
listGA = new(ngfs,string)
initdates = new(dimsizes(listF),string)
 acc_g = new(ngfs,float)    ; Anomaly Correlation Coefficient (ACC) for OTHER


; Read OTHER data
;--------------------------------------------------------------------------
; Need to loop over each OTHER file to get the actual model validation time
; anomaly_gfs(gvar, p_hPa, cvar, C_file, listGF)
do ig = 0, ngfs-1
   fgfs := addfile(listGF(ig),"r")
   xgfs := fgfs->$gvar$
   if(ig.eq.0) then
      ; Isobaric levels
      p = fgfs->lv_ISBL0 
      if(p@units.eq."Pa") then
         p = p * 0.01
         p@units = "hPa"
      end if
      k = ind(p.eq.p_hPa)

      ; Weight (along latitude)
      ylat = fgfs->lat_0
      wgty = cos(ylat({lat1(iregion):lat2(iregion)})/180.*3.141592)
      wgtx = 1.0

   dimx = dimsizes(xgfs)
   tgfs = new(ngfs,string)            ; Forecast validation time
    xgf = new((/ngfs,dimx(1),dimx(2)/),float)    ; OTHER forecast
    xga = new((/ngfs,dimx(1),dimx(2)/),float)    ; OTHER analysis
   end if
   xgf(ig,:,:) = xgfs(k,:,:)            ; OTHER forecast

  ; OTHER analysis files corresponding to the forecast validation times.
   tgfs(ig) = read_time_in_gfs_grb(xgfs)
   tstr    := str_split(tgfs(ig),"_")
   strs    := str_split(tstr(0),"-")
   shrs    := str_split(tstr(1),":")

   listGA(ig) = gfsa_dir + strs(0) + "/" + str_concat(strs) + "/gfs.0p25."+str_concat(strs) + shrs(0) + ".f000.grib2"
   ;listGA(ig) = gfsa_dir + str_concat(strs) + zulu + "/diagnostics." + tstr(0) + "_" + str_join(shrs,".")+".nc"
   print("opening "+listGA(ig))
   fgfsA := addfile(listGA(ig),"r")
    xgfs := fgfsA->$gvar$
     tga := read_time_in_gfs_grb(xgfs)
     xga(ig,:,:) = xgfs(k,:,:)            ; OTHER analysis
   
   ; Sanity check
   if(tga.ne.tgfs(ig)) then
      print("Time mismatch: "+tga+" vs. "+tgfs(ig))
      exit
   end if
end do
xgf!0 = "time"    ; => OTHER forecast ([time | 26] x [lat_0 | 361] x [lon_0 | 720])
xga!0 = "time"    ; => OTHER analysis ([time | 26] x [lat_0 | 361] x [lon_0 | 720])

; Read MPAS files (assuming that mpas analysis files are in the same diagnostic format)  
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
   do iexp = 0, nexp-2    ; Process MPAS directories
       syear = str_get_cols(cycles(icyc),0,3)
       smonth = str_get_cols(cycles(icyc),4,5)
       sday= str_get_cols(cycles(icyc),6,7)
       shour= str_get_cols(cycles(icyc),8,9)
       iyear = toint(syear)
       imonth = toint(smonth)
       iday= toint(sday)
       ihour= toint(shour)
       validjul = cd_inv_calendar(iyear,imonth,iday,ihour+fcsth,0,0,"hours since 1900-01-01 00:00:00",0)
       flist := data_dir(iexp) + cd_string(validjul, "%Y%N%D%H/diag.%Y-%N-%D_%H.%M.%S.nc")
       if(.not.isfilepresent(flist))
          print("Cannot find the forecast file."+flist)
          exit
       end if

       listA(iexp,icyc) = flist
       listF(iexp,icyc) = data_dir(iexp) + cycles(icyc) + "/" + sub_dir + systemfunc("basename "+flist)
       idate = str_index_of_substr(listF(iexp,icyc), "201", 1)
       initdates(iexp,icyc) = str_get_cols(listF(iexp,icyc), idate, idate+9) ; time of forecast initialization
   end do
end do
print("A list of MPAS analysis files:")
print(""+listA)
print("")
print("")

; Read the climate data
;--------------------------------------------------------------------------
fc = addfile(C_file,"r")
clon = fc->lon		;   [lon | 144]  (  0, 357.5 )
clat = fc->lat		;   [lat | 73]   ( 90, -90 )
clev = fc->level	; [level | 17] ( 1000, 10 )
ctim = fc->time		;  [time | 1460] [-15769752..-15760998]
xclm = fc->$cvar$	;  [time | 1460] x [level | 17] x [lat | 73] x [lon | 144]
print("Read climate data for " + xclm@long_name + " in " + xclm@units)

ck = -1
;if(clev@GRIB_name.eq.p_unit) then
if(clev@units.eq.p_unit) then
  ck = ind(clev.eq.p_hPa)
end if

; Find the time matched with MPAS forecast time (in UTC),
; matching up to the time and the day of the year
;--------------------------------------------------------------------------
nclm = dimsizes(ctim)    ;[time | 1460]
  tc = new(nclm,string)
idxF = new(ncycle,integer)
idxG = new(ngfs,integer)

 tutc = cd_calendar(ctim, 0) 
month = toint(tutc(:,1))
  day = toint(tutc(:,2))
 hour = toint(tutc(:,3))

; Don't include year (of ctim). It's 1959 or something.
tc = sprinti("%0.2i",month) + "-" + sprinti("%0.2i",day) + "_" + sprinti("%0.2i",hour) +":00:00"

do igfs = 0, ngfs-1
   date_wo_year = str_get_cols(tgfs(igfs),5,-1)
   idxG(igfs) = ind(tc.eq.date_wo_year)
   if(ismissing(idxG(igfs)))then
        print("no match for "+date_wo_year+" in tc")
        exit
   end if
end do

; Compute anomaly correlation coefficient for MPAS forecast
;--------------------------------------------------------------------------
r2d = 57.29579
do iexp = 0, nexp-2    
   fm := addfile(fmap(iexp),"r")    ; MPAS info in each MPAS grid
 xlat := fm->latCell * r2d
 xlon := fm->lonCell * r2d
 area := fm->areaCell
  ndx := dimsizes(area)
  if(iexp.eq.0) then
     printMinMax(xlon,0)
  end if

  if(region.eq."Globe") then
     idx = ispan(0,ndx-1,1)
  else
     idx := ind(xlon.ge.lon1(iregion).and.xlon.le.lon2(iregion).and.xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
     ndx := num(xlon.ge.lon1(iregion).and.xlon.le.lon2(iregion).and.xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
     area := area(idx)
  end if
  print("Processed over "+region+" ("+ndx+" cells from "+lat1(iregion)+" to "+lat2(iregion)+")")

  ; Read MPAS forecast
  fa := addfiles(listA(iexp,:),"r")
  ff := addfiles(listF(iexp,:),"r")
  ta := str_strip(tostring(fa[:]->xtime))
  tf := str_strip(tostring(ff[:]->xtime))
  if(any(ta.ne.tf)) then    ; FIXME - May need to allow different forecast times for different runs later.
     print("Time mismatch: "+ta+" vs. "+tf)
     exit
  end if
  do icyc = 0, ncycle-1
     date_wo_year = str_get_cols(tf(icyc),5,-1)
     idxF(icyc) = ind(tc.eq.date_wo_year)
  end do
  if(iexp.eq.0) then    ; FIXME - all the MPAS experiments should be available at the same cycles.
     print(fcsth + "h forecast valid at these times...")
     print(tf)
  end if
  xtimes = cd_inv_string(tostring(ff[:]->xtime),"")

  if(isfilevar(ff[0],xvar)) then
     xa := fa[:]->$xvar$
     xf := ff[:]->$xvar$
  else    ; My diagnostic files have different varable names in diagnostics files (S.Ha)
     field = str_split(xvar,"_")
     xv := field(0) + "_diag"
     pa := fa[0]->pressure_diag
     pf := ff[0]->pressure_diag
     ik := ind(pa.eq.p_hPa)
     jk := ind(pf.eq.p_hPa)
     xa := fa[:]->$xv$(:,:,ik)        ; [Time | 30] x [nCells | 40962] 
     xf := ff[:]->$xv$(:,:,jk)    ; [Time | 30] x [nCells | 40962]
  end if

; Copy xa and xf to xa_fixed and xf_fixed.
; Convert from geometric to geopotential height.
xa_fixed = xa
nCells = dimsizes(xlat)
; Use ~ahijevyc/src/ncl_shared_objects/compute_geopotential_height.so
compute_geopotential_height(ncycle, nCells, xa, xlat, xa_fixed)
xa = xa_fixed
xf_fixed = xf
compute_geopotential_height(ncycle, nCells, xf, xlat, xf_fixed)
xf = xf_fixed

 
  ; Project climate data onto the MPAS grids
  xm := xclm(idxF,ck,:,:)                 ; climate data at MPAS times [time | 30] x [lat | 73] x [lon | 144]
  xc := linint2_points_Wrap(xm&lon,xm&lat(::-1),xm(:,::-1,:),True,xlon,xlat,0)    ; [time | 30] x [pts | 40962]
  print("Climate for MPAS forecast on " + grid(iexp))
  printMinMax(xc,0)

; Compute anomalies from climatology over the subregion
  ap := xa(:,idx) - xc(:,idx)
  fp := xf(:,idx) - xc(:,idx)

; Anomaly correlation coefficient for MPAS
  do icyc = 0, ncycle-1
     aave := sum(ap(icyc,:)*area)/sum(area)    ; area-weighted mean [time | 30]
     fave := sum(fp(icyc,:)*area)/sum(area)    ; area-weighted mean [time | 30]
     aprime := ap(icyc,:) - aave
     fprime := fp(icyc,:) - fave
     astd := sqrt(sum(aprime^2.*area)/sum(area))
     fstd := sqrt(sum(fprime^2.*area)/sum(area))
     acc_m(iexp,icyc) = sum(fprime*aprime*area)/(fstd*astd*sum(area))
  end do     ;icyc = 0, ncycle-1
end do        ;do iexp = 0, nexp-2    

; Check validation times between OTHER and MPAS forecasts
;--------------------------------------------------------------------------
; First assume all the experiments are available at the same validation times.
time_matched = True     
if(ncycle.ne.ngfs) then
   time_matched = False
   print("ncycle ne ngfs")
else
   do ii = 0, ncycle-1
   if(idxF(ii).ne.idxG(ii)) then
      time_matched = False
      print("idxF.ne.idxG")
      print(ii)
      print(idxF(ii))
      print(idxG(ii))
      exit
   end if
   end do
end if

if(.not.time_matched) then
   print("OTHER  forecast times")
   print(tc(idxG)+"")
   print("")
end if

; Project climate data onto the OTHER grid
;--------------------------------------------------------------------------
if(.not.time_matched) then
   xg = xclm(idxG,ck,:,:)                 ; climate data at OTHER  times [time | 30] x [lat | 73] x [lon | 144]
else
   xg = xm
end if

opt = True
opt@bin_factor = dimsizes(xga&lat_0)*dimsizes(xga&lon_0)/dimsizes(clon)/dimsizes(clat)    ; smoothing factor from low-to-high resolution
xcg = area_conserve_remap_Wrap(xg&lon,xg&lat(::-1),xg,xga&lon_0,xga&lat_0(::-1),opt)    ;[time | 3] x [lat_0 | 361] x [lon_0 | 720]
xcg&lat_0 = xcg&lat_0(::-1)        ; flip back to N-S after flipping to S-N for area_conserve_remap_Wrap
print("Climate for OTHER forecast:")
printMinMax(xcg,0)

; Compute anomaly correlation coefficient for OTHER forecast.
; We do the same thing as above, but on 2D (lat/lon) grids.
;--------------------------------------------------------------------------
Aanom = xga - xcg
Fanom = xgf - xcg
copy_VarMeta(xga,Aanom)
copy_VarMeta(xgf,Fanom)
ap := Aanom(:,{lat1(iregion):lat2(iregion)},{lon1(iregion):lon2(iregion)})     ; Subsetting for the region of interest
fp := Fanom(:,{lat1(iregion):lat2(iregion)},{lon1(iregion):lon2(iregion)})  ; => [time | 26] x [lat_0 | 121] x [lon_0 | 720]

aave := wgt_areaave_Wrap(ap, wgty, 1., 1)        ; area-weighted mean [time]
fave := wgt_areaave_Wrap(fp, wgty, 1., 1)        ; area-weighted mean [time]
;print("Area-weighted mean: "+aave+" "+fave)

aprime := ap(0,:,:)      ; to copy metadata
fprime := fp(0,:,:)
do igfs = 0, ngfs-1
   aprime := ap(igfs,:,:) - aave(igfs)           ; [lat_0 | 121] x [lon_0 | 720]
   fprime := fp(igfs,:,:) - fave(igfs)
   astd = sqrt(wgt_areaave(aprime^2.,wgty,1.,1))
   fstd = sqrt(wgt_areaave(fprime^2.,wgty,1.,1))
   acc_g(igfs) = wgt_areaave(fprime*aprime,wgty,1.,1)/(astd*fstd)
end do

; Combining ACC for all experiments 
;--------------------------------------------------------------------------
ntime = ncycle
acc_all = new((/nexp, ntime/),float,-999.)
acc_all@_FillValue = -999.

if(time_matched) then
   acc_all(:nexp-2,:) = acc_m
   acc_all(nexp-1,:) = acc_g
else  
   print("Matching times...")
   tidx := new(ncycle+ngfs,integer)
   tidx(:ncycle-1) = idxF
   tidx(ncycle:) = idxG
   itime := get_unique_values(tidx)    ; Use NCL 6.3.0 or later.
   print(itime)
   ntime := dimsizes(itime)
   acc_all := new((/nexp, ntime/),float,-999.)
   acc_all@_FillValue = -999.
   do icyc = 0, ncycle-1
      im = ind(itime.eq.tf(icyc))
      if(ismissing(im)) then
         print("Cannot find time index im for tf "+tf(icyc)+". Stop.")
         exit
      else
         print("icyc, tf(icyc), im: "+icyc+" "+tf(icyc)+" "+im)
      end if
      acc_all(:nexp-2,im) = acc_m(:,icyc)
   end do
   do igfs = 0, ngfs-1
      ig = ind(itime.eq.tgfs(igfs))
      if(ig(0).eq.-1) then
         print("Cannot find time index ig for tgfs "+tgfs(igfs)+". Stop.")
         exit
      end if
      acc_all(nexp-1,igfs) = acc_g(igfs)
   end do
end if

; Write ACC values in the output file
;--------------------------------------------------------------------------
print("writing "+fout_asc)
; If you get a segmentation fault here, perhaps you are trying to write to a subdirectory that doesn't exist, like "out/".
write_table(fout_asc, "w", [/"init_date","valid_date","lat1","lat2","lon1","lon2",str_join(expn," ")/], "%s %s %s %s %s %s %s")
do icyc=0,ncycle-1 ; write one line at a time. Make number of acc columns dynamic as number of experiments. 
    write_table(fout_asc,"a",[/initdates(0,icyc),tf(icyc),lat1(iregion),lat2(iregion),lon1(iregion),lon2(iregion),str_join(tostring(acc_all(:,icyc))," ")/], "%s %s %f %f %f %f %s")
end do
system("ls -l " + fout_asc)
print("")

; Plot
;--------------------------------------------------------------------------
if(if_plot) then

   wks = gsn_open_wks(ffmt,ffig)
   ;stimes = str_get_cols(tc(idxF),0,9)    ;12)
   stimes = tostring(cd_calendar(xtimes, -2))

   res = True
   res@xyLineThicknessF = 10.0
   res@xyDashPatterns   = "SolidLine"   
   res@xyLineColors     = cols
   res@xyMarkLineMode = "MarkLines"
   res@xyMarkerColors = res@xyLineColors
   res@xyMarker = 16
   res@tmXBMode = "Explicit"
   res@tmXBValues = xtimes
   res@tmXBLabels = stimes
   res@tmXBLabelStride = 1
   res@tmXBLabelAngleF = 90.
   res@tmXBLabelJust = "CenterCenter"
   res@tmXBLabelFontHeightF = min((/0.024 ,0.022 * 16/ncycle/))
   res@tmXBMajorLengthF = 0.
   res@tmXMajorGrid = True
   res@tmYMajorGrid = True
   res@tmXMajorGridThicknessF = 1.0
   res@tmYMajorGridThicknessF = 1.0
   res@tmXMajorGridLineDashPattern = 2
   res@tmYMajorGridLineDashPattern = 2
   res@trYMinF = 0.6
   res@trYMaxF = 1.00
   res@tmYLLabelFontHeightF = 0.016

   ; annotation
   res@pmLegendDisplayMode    = "Always"
   res@pmLegendZone           = 0
   res@lgJustification        = "BottomLeft"
   res@pmLegendParallelPosF   =  -0.49              ; move units right
   res@pmLegendOrthogonalPosF =  0.5                ; move units down: -1.0 for an upper corner
                                                    ; the smaller (in negative), the higher
   res@pmLegendWidthF         = 0.15                ; Change width and
   res@pmLegendHeightF        = 0.13                ; height of legend. (the larger, the lower)
   res@lgPerimOn              = False               ; turn off box around
   res@lgLabelFontHeightF     = .020                ; label font size
   res@xyExplicitLegendLabels = expn

   res@tiMainString  =  xvar + " (" + region + ")"
   res@tiYAxisString = "Anomaly Correlation Coefficient"
   plot = gsn_csm_xy(wks,xtimes,acc_all,res)
   system("ls -l "+ffig+"."+ffmt)
end if
