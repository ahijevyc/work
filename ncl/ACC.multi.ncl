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
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/read_time_in_gfs_grb.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
    fcsth = 120					; forecast time to compute ACC in [hr]
     yyyy = 2016				; year for the case
     zulu = "00"				; UTC time to compute ACC
   period_of_interest = (/ "2016120[5-9]", "2016121", "2016122[0]" /)
   period_of_interest := (/ "201611[01]","2016112[0-8]","20161130", "2016120[0-35-9]", "2016121", "2016122[0]" /)

 ; Experiments and variables
 ;-------------------------------------------------------------------------
     ;grid = (/ "x1.163842","x1.40962",  "x4.133890",    "GFS004"       /)
     grid = (/ "us", "gfs.0p25"       /)
     ;expn = (/ "MPAS_60k", "MPAS_120k", "MPAS_120-30k", "GFS_0.5deg"   /)	; Experiment names (GFS should be listed as the last one).
     expn = (/ "us", "GFS"   /)	; Experiment names (GFS should be listed as the last one).
     ;cols = (/ "blue",     "green",     "red",          "black"        /)	; line colors in the plot
     cols = (/ "darkgreen",          "blue"        /)	; line colors in the plot
  sub_dir = ""              		; "warm" from EnKF analyses, "cold" from FNL analyses
  gfs_anl = "gfs.0p25"

     xvar = "height_500hPa"			; field name in mpas
     gvar = "HGT_P0_L100_GLL0" 			; field name in GFS
     cvar = "HGT_3_ISBL_S51"            	; field name in climate data
						;("hgt" for 1981-2010; "HGT_3_ISBL_S51" for 1959-1988)
    p_hPa = 500.				; isobaric level
   p_unit = "hPa"				; level unit

 ; Region of interest
 ;-------------------------------------------------------------------------
  iregion = 3					; 0-based index
  regions = (/"CONUS", "NA", "NH","Tropics","Globe"/)	
     lat1 = (/  25.,    15.,  20.,   -20.,    -90. /)
     lat2 = (/  55.,    75.,  80.,    20.,     90. /)
     lon1 = (/ 235.,   200.,   0.,     0.,      0. /)
     lon2 = (/ 285.,   305., 360.,   360.,    360. /)
   region = regions(iregion)

 ; Input directories and files
 ;-------------------------------------------------------------------------
  data_dir = (/ "/glade/scratch/syha/MPAS_DART/x1.163842.LSFC.CUT2/EXT_FCST/"     ,\
                "/glade/scratch/syha/MPAS_DART/x1.40962.LSFC.CUT2/EXT_FCST_fix/"  ,\
                "/glade/scratch/syha/MPAS_DART/x4.133890.LSFC.CUT2/EXT_FCST_fix/" /)
  data_dir := (/ "/glade/scratch/mpasrt/us/" /)
  ;anal_dir = "/glade/p/mmm/syha/MPAS_DART/FNL/" + grid + "/"
  anal_dir = data_dir
  gfsa_dir = "/glade/p/mmm/syha/GFS_ANAL/GFS004/"
  gfsa_dir = "/glade/scratch/ahijevyc/GFS/"
  ;gfsf_dir = "/glade/p/mmm/syha/GFS_FCST/"
  gfsf_dir = "/glade/scratch/ahijevyc/GFS/"
  clim_dir = "/glade/p/mmm/syha/ACC/"

 ; GFS forecast files
   ;listGF = systemfunc("ls " + gfsf_dir + yyyy + "*_i" + zulu + "_f" + fcsth + "_" + gfs_anl + ".nc")
   listGF = systemfunc("ls " + str_join(gfsf_dir + yyyy + "*"+zulu+"/"+gfs_anl+"."+period_of_interest+"*" + zulu + ".f" + fcsth + ".grib2.nc"," "))
   print(listGF)

 ; Input file names
 ;--------------------------------------------------------------------------
     fmap = "/glade/p/mmm/syha/MPAS_DART/FNL/" + grid + "/" + grid + ".init.2012052500.nc"   ; mpas grid info
     fmap = "/glade/p/work/ahijevyc/mpas_plots/"+expn(0)+"/init.nc"   ; mpas grid info
   ;F_file = grid + ".diag"				   ; mpas forecast
   F_file = "diag"				   ; mpas forecast
   C_file = clim_dir + "hgt.4Xday.1959-1988.ltm.nc"        ; climate data

 ; OUTPUT (ACC in a text file and a time series plot)
 ;--------------------------------------------------------------------------
  fout_asc = "ACC." + region + "." + xvar + "." + fcsth + "hfcst." + zulu + "Z.txt"
   if_plot = True	; Plot ACC in time series? True or False
      ffmt = "png"	; figure format
      ffig = "ACC." + region + "." + xvar + "." + fcsth + "hfcst" + "." + zulu + "Z" + "." + sub_dir
;--------------------------------------------------------------------------
; End user defined parameters
;--------------------------------------------------------------------------

print("")
print("ACC.ncl: Computing anomaly correlation coefficient in MPAS "+fcsth+" h forecast")
print("         for " + xvar)	; + " in " + xgrid )
print("")

; Time period of interest - based on the first experiment
;--------------------------------------------------------------------------
; MPAS forecast directories
;Fdirs  = systemfunc("ls -d " + data_dir(0) + yyyy + "*" + zulu )
Fdirs  = systemfunc("ls -d " + str_join(data_dir(0) + period_of_interest + "*" + zulu," "))
ncycle = dimsizes(Fdirs) 	; sample cycles
cycles = new(ncycle,string)
do icyc = 0, ncycle-1
   cycles(icyc) = systemfunc("basename "+Fdirs(icyc))
end do
print("")
print("Processing " + ncycle + " cycles...")
print(cycles+"")
print("")

xtimes = ispan(0,ncycle-1,1)
  nexp = dimsizes(expn)
 acc_m = new((/nexp-1,ncycle/),float)	; Anomaly Correlation Coefficient (ACC)

; List of files
 listA = new((/nexp-1,ncycle/),string)
 listF = new((/nexp-1,ncycle/),string)
  ngfs = dimsizes(listGF)
listGA = new(ngfs,string)
 acc_g = new(ngfs,float)	; Anomaly Correlation Coefficient (ACC) for GFS


; Read GFS data
;--------------------------------------------------------------------------
; Need to loop over each GFS file to get the actual model validation time
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
   tgfs = new(ngfs,string)			; Forecast validation time
    xgf = new((/ngfs,dimx(1),dimx(2)/),float)	; GFS forecast
    xga = new((/ngfs,dimx(1),dimx(2)/),float)	; GFS analysis
   end if
   xgf(ig,:,:) = xgfs(k,:,:)			; GFS forecast

  ; GFS analysis files corresponding to the forecast validation times.
   tgfs(ig) = read_time_in_gfs_grb(xgfs)
   tstr    := str_split(tgfs(ig),"_")
   strs    := str_split(tstr(0),"-")
   shrs    := str_split(tstr(1),":")

   ;listGA(ig) = gfsa_dir + str_concat(strs) + "_i" + shrs(0) + "_f000_" + gfs_anl + ".nc"
   listGA(ig) = gfsa_dir + str_concat(strs) + zulu + "/diagnostics." + tstr(0) + "_" + str_join(shrs,".")+".nc"
   print("opening "+listGA(ig))
   fgfsA := addfile(listGA(ig),"r")
    xgfs := fgfsA->$gvar$
     tga := read_time_in_gfs_grb(xgfs)
     xga(ig,:,:) = xgfs(k,:,:)			; GFS analysis
   
   ; Sanity check
   if(tga.ne.tgfs(ig)) then
      print("Time mismatch: "+tga+" vs. "+tgfs(ig))
      exit
   end if
end do
xgf!0 = "time"	; => GFS forecast ([time | 26] x [lat_0 | 361] x [lon_0 | 720])
xga!0 = "time"	; => GFS analysis ([time | 26] x [lat_0 | 361] x [lon_0 | 720])

; Read MPAS files (assuming that mpas analysis files are in the same diagnostic format)  
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
   do iexp = 0, nexp-2	; Process MPAS directories
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
nclm = dimsizes(ctim)	;[time | 1460]
  tc = new(nclm,string)
idxF = new(ncycle,integer)
idxG = new(ngfs,integer)

 tutc = cd_calendar(ctim, 0) 
month = toint(tutc(:,1))
  day = toint(tutc(:,2))
 hour = toint(tutc(:,3))

tc = yyyy + "-" + sprinti("%0.2i",month) + "-" + sprinti("%0.2i",day) + "_" + sprinti("%0.2i",hour) +":00:00"
do igfs = 0, ngfs-1
   idxG(igfs) = ind(tc.eq.tgfs(igfs))
end do

; Compute anomaly correlation coefficient for MPAS forecast
;--------------------------------------------------------------------------
r2d = 57.29579
do iexp = 0, nexp-2	
   fm := addfile(fmap(iexp),"r")	; MPAS info in each MPAS grid
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
  if(any(ta.ne.tf)) then	; FIXME - May need to allow different forecast times for different runs later.
     print("Time mismatch: "+ta+" vs. "+tf)
     exit
  end if
  do icyc = 0, ncycle-1
     idxF(icyc) = ind(tc.eq.tf(icyc))
  end do
  if(iexp.eq.0) then	; FIXME - all the MPAS experiments should be available at the same cycles.
     print(fcsth + "h forecast valid at these times...")
     print(tc(idxF)+" ")
  end if

  if(isfilevar(ff[0],xvar)) then
     xa := fa[:]->$xvar$
     xf := ff[:]->$xvar$
  else	; My diagnostic files have different varable names in diagnostics files (S.Ha)
     field = str_split(xvar,"_")
     xv := field(0) + "_diag"
     pa := fa[0]->pressure_diag
     pf := ff[0]->pressure_diag
     ik := ind(pa.eq.p_hPa)
     jk := ind(pf.eq.p_hPa)
     xa := fa[:]->$xv$(:,:,ik)		; [Time | 30] x [nCells | 40962] 
     xf := ff[:]->$xv$(:,:,jk)	; [Time | 30] x [nCells | 40962]
  end if
 
  ; Project climate data onto the MPAS grids
  xm := xclm(idxF,ck,:,:)		         ; climate data at MPAS times [time | 30] x [lat | 73] x [lon | 144]
  xc := linint2_points_Wrap(xm&lon,xm&lat(::-1),xm(:,::-1,:),True,xlon,xlat,0)	; [time | 30] x [pts | 40962]
  print("Climate for MPAS forecast on " + grid(iexp))
  printMinMax(xc,0)

; Compute anomalies from climatology over the subregion
  ap := xa(:,idx) - xc(:,idx)
  fp := xf(:,idx) - xc(:,idx)

; Anomaly correlation coefficient for MPAS
  do icyc = 0, ncycle-1
     aave := sum(ap(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
     fave := sum(fp(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
     aprime := ap(icyc,:) - aave
     fprime := fp(icyc,:) - fave
     astd := sqrt(sum(aprime^2.*area)/sum(area))
     fstd := sqrt(sum(fprime^2.*area)/sum(area))
     acc_m(iexp,icyc) = sum(fprime*aprime*area)/(fstd*astd*sum(area))
  end do 	;icyc = 0, ncycle-1
end do		;do iexp = 0, nexp-2	

; Check validation times between GFS and MPAS forecasts
;--------------------------------------------------------------------------
; First assume all the experiments are available at the same validation times.
time_matched = True 	
if(ncycle.ne.ngfs) then
   time_matched = False
else
   do ii = 0, ncycle-1
   if(idxF(ii).ne.idxG(ii)) then
      time_matched = False
   end if
   end do
end if

if(.not.time_matched) then
   print("GFS  forecast times")
   print(tc(idxG)+"")
   print("")
end if

; Project climate data onto the GFS grid
;--------------------------------------------------------------------------
if(.not.time_matched) then
   xg = xclm(idxG,ck,:,:)		         ; climate data at GFS  times [time | 30] x [lat | 73] x [lon | 144]
else
   xg = xm
end if

opt = True
opt@bin_factor = dimsizes(xga&lat_0)*dimsizes(xga&lon_0)/dimsizes(clon)/dimsizes(clat)    ; smoothing factor from low-to-high resolution
xcg = area_conserve_remap_Wrap(xg&lon,xg&lat(::-1),xg,xga&lon_0,xga&lat_0(::-1),opt)    ;[time | 3] x [lat_0 | 361] x [lon_0 | 720]
xcg&lat_0 = xcg&lat_0(::-1)		; flip back to N-S after flipping to S-N for area_conserve_remap_Wrap
print("Climate for GFS forecast:")
printMinMax(xcg,0)

; Compute anomaly correlation coefficient for GFS forecast.
; We do the same thing as above, but on 2D (lat/lon) grids.
;--------------------------------------------------------------------------
Aanom = xga - xcg
Fanom = xgf - xcg
copy_VarMeta(xga,Aanom)
copy_VarMeta(xgf,Fanom)
ap := Aanom(:,{lat1(iregion):lat2(iregion)},{lon1(iregion):lon2(iregion)}) 	; Subsetting for the region of interest
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
   itime := get_unique_values(tidx)	; Use NCL 6.3.0 or later.
   ntime := dimsizes(itime)
   acc_all := new((/nexp, ntime/),float,-999.)
   acc_all@_FillValue = -999.
   do icyc = 0, ncycle-1
      im = ind(itime.eq.tf(icyc))
      if(ismissing(im)) then
         print("Cannot find time index for "+tf(icyc)+". Stop.")
         exit
      else
         print("icyc, tf(icyc), im: "+icyc+" "+tf(icyc)+" "+im)
      end if
      acc_all(:nexp-2,im) = acc_m(:,icyc)
   end do
   do igfs = 0, ngfs-1
      ig = ind(itime.eq.tgfs(igfs))
      if(ig(0).eq.-1) then
         print("Cannot find time index for "+tgfs(igfs)+". Stop.")
         exit
      end if
      acc_all(nexp-1,igfs) = acc_g(igfs)
   end do
end if

; Write ACC values in the output file
;--------------------------------------------------------------------------
anno = new(nexp,string)
titl_out = ""
mean_out = ""
data_str = new(ncycle+2,string)
data_out = new((/ncycle+2,nexp+1/),string)
data_out = ""
data_out(0,0)        = "     Time          "
data_out(ncycle+1,0) = "     AVERAGE       "    
data_out(1:ncycle,0) = tc(idxF)
do iexp = 0, nexp-1
   titl_out = titl_out + expn(iexp) + " "
   mean_out = mean_out + avg(acc_all(iexp,:)) + " "
   do icyc = 0, ncycle-1
      data_out(icyc+1,iexp+1) = sprintf("%10.5f",acc_all(iexp,icyc))
   end do
   data_out(ncycle+1,iexp+1) = sprintf("%10.5f",avg(acc_all(iexp,:)))
   anno(iexp) = expn(iexp) + sprintf("%10.5f",avg(acc_all(iexp,:)))
end do
titl_out = "     Time            " + titl_out
data_str(0) = titl_out
do icyc = 1, ncycle+1
data_str(icyc) = str_concat(data_out(icyc,:))
end do
print("")
print("Anomaly Correlation Coefficient over "+region)
print(""+data_str)

asciiwrite(fout_asc,data_str)
system("ls -l " + fout_asc)
print("")

; Plot
;--------------------------------------------------------------------------
if(if_plot) then

   wks = gsn_open_wks(ffmt,ffig)
   stimes = str_get_cols(tc(idxF),0,9)	;12)

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
   res@trYMinF = 0.8
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
   res@xyExplicitLegendLabels = anno

   res@tiMainString  =  xvar + " (" + region + ")"
   res@tiYAxisString = "Anomaly Correlation Coefficient"
   plot = gsn_csm_xy(wks,xtimes,acc_all,res)
   system("ls -l "+ffig+"."+ffmt)
end if
