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
load "/glade/p/work/ahijevyc/ncl/read_time_in_gfs_grb.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
    xgrid = "x1.163842"				; mpas grid mesh
    fcsth = 48					; forecast time to compute ACC in [hr]
    fintv = 24 					; forecast interval (to find the forecast file at {fcsth} hr lead.)
     yyyy = 2015050				; year for the case
     zulu = "00"				; UTC time to compute ACC

 ; Experiments and variables
 ;-------------------------------------------------------------------------
     expn = (/ "MPAS", "GFS"   /)		; Experiment names (only 2 datasets are allowed for now.)
     expn := (/ "MPAS"  /)		; Experiment names (only 2 datasets are allowed for now.)
     cols = (/ "red",  "blue"  /)		; line colors in the plot
     cols := (/ "red" /)		; line colors in the plot
  sub_dir = (/ "cold", "GFS004" /) 		; "warm" from EnKF analyses, "cold" from FNL analyses

     xvar = (/ "height_500hPa", "HGT_P0_L100_GLL0" /)	; field names in each experiment
     xvar := (/ "height_500hPa" /)	; field names in each experiment
     cvar = "HGT_3_ISBL_S51"            	; climate data variable name 
						;("hgt" for 1981-2010; "HGT_3_ISBL_S51" for 1959-1988)
    p_hPa = 500.				; isobaric level
   p_unit = "hPa"				; level unit

 ; Region of interest
 ;-------------------------------------------------------------------------
  iregion = 0					; 0-based index
  regions = (/"NH","Tropics","Globe"/)	
     lat1 = (/ 20.,   -20.,    -90. /)
     lat2 = (/ 80.,    20.,     90. /)
   region = regions(iregion)

 ; Input directories and files
 ;-------------------------------------------------------------------------
  ;mpas_dir = "/glade/p/nmmm0024/syha/MPAS_DART/Spring2012/x1.163842/EXT_FCST/"
  ;mpas_dir = "/glade/p/nmmm0024/mpas_ep/"
  mpas_dir = "/glade/scratch/ahijevyc/mpas50_3/"
  ;anal_dir = "/glade/p/nmmm0024/syha/MPAS_DART/FNL/" + xgrid + "/"
  ;anal_dir = "/glade/p/nmmm0024/mpas_ep/"
  anal_dir = "/glade/scratch/ahijevyc/mpas50_3/"
  ;gfsa_dir = "/glade/p/mmm/syha/GFS_ANAL/GFS004/"
  gfsa_dir = "/glade/scratch/ahijevyc/GFS/"
  ;gfsf_dir = "/glade/p/mmm/syha/GFS_FCST/"
  gfsf_dir = gfsa_dir
  clim_dir = "/glade/p/mmm/syha/ACC/"

 ; MPAS forecast directories
   Fdirs  = systemfunc("ls -d " + mpas_dir + yyyy + "*" + zulu )
 ; GFS forecast files
   ;listGF = systemfunc("ls " + gfsf_dir + yyyy + "*_i" + zulu + "_f" + sprintf("%03d",fcsth) + "_" + sub_dir(1) + ".nc")
   listGF = systemfunc("ls " + gfsf_dir + yyyy + "*/diag*" + str_get_cols(yyyy,0,3) + "-*00.nc")

 ; Input file names
 ;--------------------------------------------------------------------------
     ;fmap = "/glade/p/nmmm0024/syha/MPAS_DART/FNL/" + xgrid + "/" + xgrid + ".init.2012052500.nc"   ; mpas grid info
     ;fmap = "/glade/p/work/syha/MPAS_DART/FNL/" + xgrid + "/" + xgrid + ".init.2012052500.nc"   ; mpas grid info
     ;fmap = anal_dir + "2014090100/init.nc"		; mpas grid info
     fmap = anal_dir + "2015050100/init.nc"		; mpas grid info
   ;F_file = xgrid + ".diag"				   ; mpas forecast
   F_file = "diag"				   ; mpas forecast
   C_file = clim_dir + "hgt.4Xday.1959-1988.ltm.nc"        ; climate data

 ; OUTPUT (ACC in a text file and a time series plot)
 ;--------------------------------------------------------------------------
  fout_asc = xgrid + "." + sub_dir(0) + ".ACC." + region + "." + xvar(0) + "." + fcsth + "hfcst." + zulu + "Z.txt"
   if_plot = True	; Plot ACC in time series? True or False
      ffmt = "png"	; figure format
      ;ffig = "ACC." + region + "." + xvar(0) + "." + fcsth + "hfcst" + "." + zulu + "Z" + "." + sub_dir(0)
      ffig = "ACC." + region + "." + xvar(0) + "." + fcsth + "hfcst" + "." + zulu + "Z"
;--------------------------------------------------------------------------
; End user defined parameters
;--------------------------------------------------------------------------

print("")
print("ACC.ncl: Computing anomaly correlation coefficient in MPAS "+fcsth+" h forecast")
print("         for " + xvar + " in " + xgrid )
print("")

; Map info in the MPAS unstructured mesh
;--------------------------------------------------------------------------
fm = addfile(fmap,"r")
r2d = 57.29579
xlat = fm->latCell * r2d
xlon = fm->lonCell * r2d
area = fm->areaCell
 ndx = dimsizes(area)

if(region.eq."Globe") then
   idx = ispan(0,ndx-1,1)
else
   idx = ind(xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   ndx = num(xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   area := area(idx)
end if
print("         processed over "+region+" ("+ndx+" cells from "+lat1(iregion)+" to "+lat2(iregion)+")")

; Time period of interest
;--------------------------------------------------------------------------
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
 acc_m = new(ncycle,double)	; Anomaly Correlation Coefficient (ACC)

; List of files
 listA = new(ncycle,string)
 listF = new(ncycle,string)
  ngfs = dimsizes(listGF)
listGA = new(ngfs,string)
 acc_g = new(ngfs,double)	; Anomaly Correlation Coefficient (ACC) for GFS


if(.not.any(ismissing(str_match(expn, "GFS")))) then
; Read GFS data
;--------------------------------------------------------------------------
; Need to loop over each GFS file to get the actual model validation time
do ig = 0, ngfs-1
   fgfs := addfile(listGF(ig),"r")
   xgfs := fgfs->$xvar(1)$
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

   ;listGA(ig) = gfsa_dir + str_concat(strs) + "_i" + shrs(0) + "_f000_" + sub_dir(1) + ".nc"
   listGA(ig) = gfsa_dir + str_concat(strs) + zulu + "/diagnostics."+tstr(0)+"_00.00.00.nc"
   fgfsA := addfile(listGA(ig),"r")
    xgfs := fgfsA->$xvar(1)$
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
end if

; Read MPAS files (assuming that mpas analysis files are in the same diagnostic format)  
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
   ;flist := systemfunc("csh -c 'cd " + Fdirs(icyc) + "/" + sub_dir(0) + "; ls " + F_file + "*.nc'")
   flist := systemfunc("csh -c 'cd " + Fdirs(icyc) +"; ls " + F_file + "*.nc'")
   nlist := dimsizes(flist)
   fhrs  := ispan(0,(nlist-1)*fintv, fintv)
   ifcst := ind(fhrs.eq.fcsth)
   ;if(ifcst(0).eq.-1) then
   if(any(ismissing(ifcst))) then
      print("Cannot find the forecast file.")
      print(nlist)
      print(fintv)	
      exit
   else
      if(icyc.eq.0) then
         print("=== Find the "+ifcst+"th file for "+fcsth+" hr forecast ===")
      end if
   end if
   ;listA(icyc) = anal_dir + flist(ifcst)
   tstr := str_split(flist(ifcst),"_")
   tstr := str_split(tstr(0),".")
   strs    := str_split(tstr(1),"-")
   listA(icyc) = anal_dir + str_concat(strs) + zulu + "/" + flist(ifcst)
   ;listF(icyc) = Fdirs(icyc) + "/" + sub_dir(0) + "/" + flist(ifcst)
   listF(icyc) = Fdirs(icyc) + "/" + flist(ifcst)
end do
print("A list of MPAS analysis files:")
print(""+listA)
print("")

print("A list of MPAS fcst files:")
print(""+listF)
print("")

fa = addfiles(listA,"r")
ff = addfiles(listF,"r")
ta = str_strip(tostring(fa[:]->xtime))
tf = str_strip(tostring(ff[:]->xtime))
if(any(ta.ne.tf)) then
   print("Time mismatch: "+ta+" vs. "+tf)
   exit
end if

if(isfilevar(ff[0],xvar(0))) then
   xa = fa[:]->$xvar(0)$
   xf = ff[:]->$xvar(0)$
else	; My diagnostic files have different varable names in diagnostics files (S.Ha)
   field = str_split(xvar(0),"_")
   xv := field(0) + "_diag"
    p := ff[0]->pressure_diag
    k := ind(p.eq.p_hPa)
   xa := fa[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
   xf := ff[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
end if
;printVarSummary(xf)
 
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
month  = toint(tutc(:,1))
day    = toint(tutc(:,2))
hour   = toint(tutc(:,3))

tc = str_get_cols(yyyy,0,3) + "-" + sprinti("%0.2i",month) + "-" + sprinti("%0.2i",day) + "_" + sprinti("%0.2i",hour) +":00:00"

do icyc = 0, ncycle-1
   idxF(icyc) = ind(tc.eq.tf(icyc))
end do
do igfs = 0, ngfs-1
   idxG(igfs) = ind(tc.eq.tgfs(igfs))
end do

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

print("")
print(fcsth + "h forecast valid at these times...")
print(tc(idxF)+" ")
if(.not.time_matched) then
   print("GFS  forecast times")
   print(tc(idxG)+"")
end if
print("")

; Project climate data onto the MPAS grid
;--------------------------------------------------------------------------
xm = xclm(idxF,ck,:,:)		         ; climate data at MPAS times [time | 30] x [lat | 73] x [lon | 144]
xc = linint2_points_Wrap(xm&lon,xm&lat(::-1),xm(:,::-1,:),True,xlon,xlat,0)	; [time | 30] x [pts | 40962]
print("Climate for MPAS forecast:")
printMinMax(xc,0)

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

; Compute anomaly correlation coefficient for MPAS forecast
;--------------------------------------------------------------------------
; Compute anomalies from climatology over the subregion
ap = xa(:,idx) - xc(:,idx)
fp = xf(:,idx) - xc(:,idx)

do icyc = 0, ncycle-1
   aave = sum(ap(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   fave = sum(fp(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   aprime = ap(icyc,:) - aave
   fprime = fp(icyc,:) - fave
   astd = sqrt(sum(aprime^2.*area)/sum(area))
   fstd = sqrt(sum(fprime^2.*area)/sum(area))
   acc_m(icyc) = sum(fprime*aprime*area)/(fstd*astd*sum(area))
end do
print("")

; Compute anomaly correlation coefficient for GFS forecast
; We do the same thing as above, but on 2D (lat/lon) grids.
;--------------------------------------------------------------------------
Aanom = xga - xcg
Fanom = xgf - xcg
copy_VarMeta(xga,Aanom)
copy_VarMeta(xgf,Fanom)
ap := Aanom(:,{lat1(iregion):lat2(iregion)},:) 	; Subsetting for the region of interest
fp := Fanom(:,{lat1(iregion):lat2(iregion)},:)  ; => [time | 26] x [lat_0 | 121] x [lon_0 | 720]

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
   acc_all(0,:) = tofloat(acc_m)
   acc_all(1,:) = tofloat(acc_g)
else  
   print("Matching times...")
   ;tidx := new(ncycle+ngfs,integer)
   tidx := new(ncycle+ngfs,string)
   tidx(:ncycle-1) = tc(idxF)
   tidx(ncycle:) = tc(idxG)
   itime := get_unique_values(tidx)	; Use NCL 6.3.0 and later.
   ntime := dimsizes(itime)
   acc_all := new((/nexp, ntime/),float,-999.)
   acc_all@_FillValue = -999.
   do icyc = 0, ncycle-1
      im = ind(itime.eq.tf(icyc))
      if(any(ismissing(im))) then
         print("Cannot find time index for tf "+tf(icyc)+". Stop.")
         print(itime)
         print(tf)
         exit
      end if
      acc_all(0,im) = tofloat(acc_m(icyc))
   end do
   do igfs = 0, ngfs-1
      ig = ind(itime.eq.tgfs(igfs))
      if(any(ismissing(ig))) then
         print("Cannot find time index for tgfs "+tgfs(igfs)+". Stop.")
         exit
      end if
      acc_all(1,igfs) = tofloat(acc_g(igfs))
   end do
end if

; Write ACC values in the output file
;--------------------------------------------------------------------------
data_out = tc(idxF) + sprintf("%10.5f",acc_all(0,:)) + sprintf("%10.5f",acc_all(1,:))
print("   Time      " + expn(0) + "      " + expn(1))
print(""+data_out)
print("AVERAGE:   "+avg(acc_all(0,:))+" "+avg(acc_all(1,:)))
print("")
asciiwrite(fout_asc, data_out)
system("ls -l " + fout_asc)

; Plot
;--------------------------------------------------------------------------
if(if_plot) then

   wks = gsn_open_wks(ffmt,ffig)
   anno = new(nexp,string)
   do iexp = 0, nexp-1
      anno(iexp) = expn(iexp) + sprintf("%7.3f",avg(acc_all(iexp,:)))
   end do

   stimes = str_get_cols(tc(idxF),5,12)

   res = True
   res@xyLineThicknessF = 5.0
   res@xyDashPatterns   = "SolidLine"   
   res@xyLineColors     = cols
   res@xyMarkLineMode = "MarkLines"
   res@xyMarkerColors = res@xyLineColors
   res@xyMarker = 16
   res@tmXBMode = "Explicit"
   res@tmXBValues = xtimes
   res@tmXBLabels = stimes
   res@tmXBLabelStride = 2
   res@tmXBLabelAngleF = 90.
   res@tmXBLabelJust = "TopLeft"
   res@trYMinF = 0.60
   res@trYMaxF = 1.00

   ; annotation
   res@pmLegendDisplayMode    = "Always"
   res@pmLegendParallelPosF   =  0.20                  ; move units right
   res@pmLegendOrthogonalPosF =  -0.45             ; move units down: -1.0 for an upper corner
                                                ; the smaller (in negative), the higher
   res@pmLegendWidthF         = 0.13                ; Change width and
   res@pmLegendHeightF        = 0.10                ; height of legend. (the larger, the lower)
   res@lgPerimOn              = False               ; turn off box around
   res@lgLabelFontHeightF     = .020               ; label font height
   res@xyExplicitLegendLabels = anno

   res@tiMainString  = xgrid + ": " + xvar(0) + " (" + region + ")"
   res@tiYAxisString = "ACC"
   plot = gsn_csm_xy(wks,xtimes,acc_all,res)
   system("ls -l "+ffig+"."+ffmt)
end if
