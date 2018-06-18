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
;load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade2/work/ahijevyc/ncl/read_time_in_gfs_grb.ncl"
load "/glade2/work/ahijevyc/ncl/cd_inv_string.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
    x_var = "height"				; field name
    p_hPa = 500.				; isobaric level
   p_unit = "hPa"				; level unit
     xvar = x_var + "_" + p_hPa + p_unit	; mpas forecast variable name
     cvar = "HGT_3_ISBL_S51"				; climate data variable name
     pvar = "pressure_diag"
     yyyy = 2017	; year for the case
     zulu = "00"	; UTC time to compute ACC

 ; Region of interest
 ;-------------------------------------------------------------------------
  iregion = 5                    ; 0-based index
;                0       1     2        3      4     5      6
  regions = (/"CONUS", "NA", "NH","Tropics", "SH","Globe","WP"/)    
     lat1 = (/  25.,    15.,  20.,   -20.,   -80., -90.,  -10. /)
     lat2 = (/  55.,    75.,  80.,    20.,   -20.,  90.,   50. /)
     lon1 = (/ 235.,   200.,   0.,     0.,     0.,   0.,  100. /)
     lon2 = (/ 285.,   305., 360.,   360.,   360., 360.,  210. /)
   region = regions(iregion)

  sub_dir = ""	; "warm" from EnKF analyses, "cold" from FNL analyses
     desc = "GMTED2010"
 clim_dir = "/glade/p/mmm/syha/ACC/"
; anal_dir = "/glade/p/nmmm0024/syha/MPAS_DART/FNL/" + xgrid + "/"
expn_name = sub_dir

   F_file = "diag"			; mpas forecast
   C_file = clim_dir+"hgt.4Xday.1959-1988.ltm.nc"	; climate data
     fmap = "/glade2/work/ahijevyc/mpas_plots/uni/init.nc"		; mpas static info

 ; OUTPUT (ACC in a text file and a time series plot)
 ;--------------------------------------------------------------------------
   fout_name = "out/ACC." + region + "." + xvar + ".120hfcst." + zulu + "Z." + desc + "." + sub_dir 
   fout_asc = fout_name + ".txt"
   if_plot = True    ; Plot ACC in time series? True or False
      ffmt = "png"    ; figure format
      ffig = fout_name
;--------------------------------------------------------------------------
; End user defined parameters
;--------------------------------------------------------------------------

print("")
print("ACC.ncl: Computing anomaly correlation coefficient in MPAS forecasts")	;
print("         for " + xvar + " in " + expn_name)
print("")

; Map info in the MPAS unstructured mesh
;--------------------------------------------------------------------------
fm = addfile(fmap,"r")
r2d = 57.29578
xlat = fm->latCell * r2d
xlon = fm->lonCell * r2d
area = fm->areaCell
 ndx = dimsizes(area)

if(region.eq."Globe") then
   idx = ispan(0,ndx-1,1)
else
   idx = ind(xlon.ge.lon1(iregion).and.xlon.le.lon2(iregion).and.xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   ndx := num(xlon.ge.lon1(iregion).and.xlon.le.lon2(iregion).and.xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   area := area(idx)
end if
print("         processed over "+region+" ("+ndx+" cells)")

; MPAS analysis and forecast files
;--------------------------------------------------------------------------

listA := (/ \
           "/glade/scratch/mpasrt/uni/2017010600/diag.2017-01-06_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017010900/diag.2017-01-09_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011200/diag.2017-01-12_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011500/diag.2017-01-15_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011800/diag.2017-01-18_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012100/diag.2017-01-21_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012400/diag.2017-01-24_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012700/diag.2017-01-27_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017013000/diag.2017-01-30_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017020200/diag.2017-02-02_00.00.00.nc"/)
listF := (/ \
           "/glade/scratch/mpasrt/uni/2017010100/diag.2017-01-06_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017010400/diag.2017-01-09_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017010700/diag.2017-01-12_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011000/diag.2017-01-15_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011300/diag.2017-01-18_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011600/diag.2017-01-21_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017011900/diag.2017-01-24_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012200/diag.2017-01-27_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012500/diag.2017-01-30_00.00.00.nc",\
           "/glade/scratch/mpasrt/uni/2017012800/diag.2017-02-02_00.00.00.nc"/)



;listA := listA(0:6)
;listF := listF(0:6)

ncycle = dimsizes(listA)
 acc_t = new((/2,ncycle/),float)	; final output - Anomaly Correlation Coefficient (ACC)
fa = addfiles(listA, "r")
ff = addfiles(listF, "r")
ta = str_strip(tostring(fa[:]->xtime))
tf = str_strip(tostring(ff[:]->xtime))
xtimes = cd_inv_string(tostring(ff[:]->xtime),"")
if(any(tf.ne.ta)) then
   print("Time mismatch: "+ta+" vs. "+tf)
   exit
end if

initdates = new(dimsizes(listF),string)

; Read the forecast field (F)
;--------------------------------------------------------------------------
if(isfilevar(ff[0],xvar)) then
   xa = fa[:]->$xvar$
   xf = ff[:]->$xvar$
else
   xv = x_var + "_diag"
    p = ff[0]->$pvar$
    k = ind(p.eq.p_hPa)
   xa = fa[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
   xf = ff[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
end if

; Copy xa and xf to xa_fixed and xf_fixed.
; Convert from geometric to geopotential height.
xa_fixed = xa
nCells = dimsizes(xlat)
; Use ~ahijevyc/src/ncl_shared_objects/compute_geopotential_height.so
dimsizes_xa=dimsizes(xa)
if(nCells.ne.dimsizes_xa(1))then
    print(nCells)
    printVarSummary(xa)
    print("nCells doesn't equal size of dim 1 in xa")
    print("did you define correct init.nc file: "+fmap)
end if
compute_geopotential_height(ncycle, nCells, xa, xlat, xa_fixed)
xf_fixed = xf
compute_geopotential_height(ncycle, nCells, xf, xlat, xf_fixed)

; Create arrays with extra dimension to hold unfixed and fixed heights.
xa2 := new((/2,ncycle,nCells/),typeof(xa))
xa2(0,:,:) = xa
xa2(1,:,:) = xa_fixed

xf2 := new((/2,ncycle,nCells/),typeof(xf))
xf2(0,:,:) = xf
xf2(1,:,:) = xf_fixed

anno = (/ "unfixed",   "fixed" /)
cols = (/ "darkgreen", "green" /)	; line colors in the plot

do iexp=0,1
xf := xf2(iexp,:,:)
xa := xa2(iexp,:,:)
 
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
if(clev@units.eq.p_unit) then
  ck = ind(clev.eq.p_hPa)
end if

; Find the time matched with MPAS forecast time (in UTC),
; matching up to the time and the day of the year
;--------------------------------------------------------------------------
nclm = dimsizes(ctim)    ;[time | 1460]
  tc = new(nclm,string)
idxF = new(ncycle,integer)

 tutc = cd_calendar(ctim, 0) 
month = toint(tutc(:,1))
  day = toint(tutc(:,2))
 hour = toint(tutc(:,3))

tc = yyyy + "-" + sprinti("%0.2i",month) + "-" + sprinti("%0.2i",day) + "_" + sprinti("%0.2i",hour) +":00:00"
do icyc = 0, ncycle-1
   idxF(icyc) = ind(tc.eq.tf(icyc))
   idate = str_index_of_substr(listF(icyc), "201", 1)
   initdates(icyc) = str_get_cols(listF(icyc), idate, idate+9) ; time of forecast initialization
end do

print(idxF)
print("Analysis/Forecast time   Initialization time")
print(""+tc(idxF) + " " + initdates)
print("")

; Project climate data onto the MPAS grid
;--------------------------------------------------------------------------
xm = xclm(idxF,ck,:,:)		         ; climate data at analysis times [time | 30] x [lat | 73] x [lon | 144]
ca = linint2_points_Wrap(xm&lon,xm&lat(::-1),xm(:,::-1,:),True,xlon,xlat,0)	; [time | 30] x [pts | 40962]
printMinMax(ca,0)
printMinMax(xa,0)

; Compute anomalies from climatology
;--------------------------------------------------------------------------
ap = xa(:,idx) - ca(:,idx)
fp = xf(:,idx) - ca(:,idx)
printVarSummary(ap)
printVarSummary(area)

; Compute anomaly correlation coefficient
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
   aave = sum(ap(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   fave = sum(fp(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   aprime = ap(icyc,:) - aave
   fprime = fp(icyc,:) - fave
   astd = sqrt(sum(aprime^2.*area)/sum(area))
   fstd = sqrt(sum(fprime^2.*area)/sum(area))
   acc_t(iexp,icyc) = sum(fprime*aprime*area)/(fstd*astd*sum(area))
end do
print(tc(idxF)+" "+acc_t(iexp,:))
print("AVERAGE:"+avg(acc_t(iexp,:)))

end do

; Write ACC values in the output file
;--------------------------------------------------------------------------
write_table(fout_asc, "w", [/"init_date","valid_date","lat1","lat2","lon1","lon2",str_join(anno," ")/], "%s %s %s %s %s %s %s")
do icyc=0,ncycle-1 ; write one line at a time. Make number of acc columns dynamic as number of experiments. 
    write_table(fout_asc,"a",[/initdates(icyc),tc(idxF(icyc)),lat1(iregion),lat2(iregion),lon1(iregion),lon2(iregion),acc_t(0,icyc),acc_t(1,icyc)/], "%s %s %f %f %f %f %f %f")
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
   res@xyExplicitLegendLabels = anno

   res@tiMainString  =  xvar + " (" + region + ")"
   res@tiYAxisString = "Anomaly Correlation Coefficient"
   plot = gsn_csm_xy(wks,xtimes,acc_t,res)
   system("ls -l "+ffig+"."+ffmt)
end if
