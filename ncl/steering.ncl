;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
;load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_inv_string.ncl"
load "/glade/work/ahijevyc/ncl/cd_inv_string.ncl"
; refer to my copy of wgt_vertical_n. It wraps metadata. 6.4.0 version does not.
load "/glade/work/ahijevyc/ncl/wgt_vertical_n_Wrap.ncl"
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/remove_storm.ncl"
load "/glade/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/work/ahijevyc/ncl/CreateTracks.ncl"
external AHIJ "/glade/u/home/ahijevyc/src/ncl_shared_objects/dpres_plevel_dp.so"
;=============================================================================================

begin

; Analyze steering flow around storm
;
; Types of input data that can be read:
; 	WRF initialized with GFS or GEFS
;	ECMWF analysis (ECMWFa.2015093000 ECMWFa.2015093006)
;	ECMWF TIGGE forecasts (EMX.2015093000 EMX.2015093012)
;	GFS from /glade/collections/rda/data/ds084.1/2016/20160827/gfs.0p25.2016*
;
; Input:
;	ensmember: basename of file with storm track (in same directory as execution directory) ; used for output filename, text output column 1, determining filetype...probably should be 
;	rx : (float) radius of storm in degrees (default 4.)
;	fhr : forecast hour (default 48)
;	file_ncl: file to process
;	ptop: top pressure level in hPa (default 250.)
;	pbot: bottom pressure level in hPa (default 850.)
;	besttrack: TC best track
;	modeltrack: model storm track (Optional. If missing, use besttrack)
;	force_new: True or False, force new files if they exist already.(default False)
;
; Output:
;	PNG: plot
;		file name = ensmember+"."+steeringflowstr+"."+stormradstr+"."+sprintf("%03.0f",fhr)
;		observed storm track
;		model storm track
;		black circle denoting current storm location and radius
;		environmental wind speed and barbs
;		storm motion (12-h average centered on current time)
;		deviation of storm motion from steering flow
;		environmental wind shear magnitude and heading
;	
;	text: diagnostics
;		environmental shear
;		storm movement
;		steering flow
;		storm movement - steering flow 
;		file name is same as PNG except with ".txt" suffix.
;			
;	netCDF: diagnostic output if nc_output = True
;		File name is held in the resource remove_storm_res@ofile.
;		File name is same as PNG except with '.nc' suffix.
;		Change this resource if you want to change the output file name.
;		Output fields:
;		These diagnostic fields are all layer-averages. 
;			U:	(2d) zonal wind
;			V:	(2d) meridional wind
;			div:	(2d) divergence
;			vrt: 	(2d) vorticity
;			ndiv:	(2d) div within rx deg of storm
;			nvrt:	(2d) vrt within rx deg of storm
; 			uc:	(2d) zonal wind component of ndiv
;			vc:	(2d) meridional wind component of ndiv
; 			up:	(2d) zonal wind component of nvrt
;			vp:	(2d) meridional wind component of nvrt
;			UR:	(2d) (U-uc-up) zonal wind without storm (steering flow)
;			VR:	(2d) (V-vc-vp) meridonal wind without storm (steering flow)
;			divR:	(2d) divergence without storm
;			vrtR:	(2d) vorticity without storm
;			Uavg:	(scalar) mean UR within rx deg of storm (zonal component of steering flow)
;			Vavg:	(scalar) mean VR within rx deg of storm (meridional component of steering flow)


if(.not.isvar("fhr")) then
	fhr= 48
end if
if(.not.isvar("nc_output")) then
	nc_output = False
end if
if(.not.isvar("force_new")) then
	force_new = False
end if
if(.not.isvar("besttrack")) then
    besttrack = "/glade/work/ahijevyc/atcf/archive/2015/bal112015.dat"
end if
if(.not.isvar("modeltrack")) then
    modeltrack = besttrack
end if
if(.not.isvar("ensmember")) then
	ensmember = "gep20.2015093000" ; for actual gefs forecast, not WRF initialized with it.
	ensmember = "ECMWFa.2015093000"
	ensmember = "GFSO"
end if

bdeck = read_atcf(besttrack)
stormname = bdeck@stormname
track_files = (/ besttrack, modeltrack /)

; Sanity check. Make sure all track files exist before proceeding.
do i=0,dimsizes(track_files)-1
	if(.not.fileexists(track_files(i)))then
		print("one of the track files doesn't exist: "+track_files(i))
		exit
	end if
end do

if(.not.isvar("file_ncl")) then
	file_ncl = "/glade/scratch/weiwang/v371/WRFV3/jq/test1_"+ensmember+"/wrfout_d01_2015-10-02_00:00:00.nc"
	;file_ncl = "/glade/scratch/weiwang/v371/WPS/"+ensmember+"/met_em.d01.2015-10-01_18:00:00.nc"
	if(str_get_cols(ensmember,0,2).eq."gep")then
		file_ncl = "/glade/scratch/weiwang/joaquin/gep"+str_get_cols(ensmember,3,4)+".t00z.pgrb2af"+sprintf("%02.0f",fhr)+".grb2"
	end if
	if(.not.ismissing(str_match(ensmember,"EMX.")))then
		date=str_get_cols(ensmember,str_index_of_substr(ensmember,".",-1)+1,-1)
		file_ncl = "/glade/scratch/ahijevyc/ECMWF/"+date+"/"+date+".grb"
	end if
	if(.not.ismissing(str_match(ensmember,"ECMWFa.")))then
		if(fhr.ne.0)then
			exit
		end if
		date=str_get_cols(ensmember,str_index_of_substr(ensmember,".",-1)+1,-1)
        print(date)
		file_ncl="/glade/scratch/weiwang/v371/WPS/ec/met_em.d01."+cd_string(cd_inv_string(date,format),"%Y-%N-%D_%H:%M:%S")+".nc"
	end if
end if
if(.not.isvar("rx")) then 
	rx = 4.
end if
remove_storm_res = True
remove_storm_res@units = "degrees"
rx := tofloat(rx) ; for nggcog function (called in CreateTracks.ncl)
remove_storm_res@rx = rx
if(.not.isvar("pbot")) then
	pbot = 850.
end if
if(.not.isvar("ptop")) then
	ptop = 250.
end if
steeringflowstr = sprintf("%.0f",pbot)+"-"+sprintf("%.0f",ptop)+"hPa"
stormradstr = sprintf("%.1f",remove_storm_res@rx)+remove_storm_res@units
output_file = ensmember+"."+steeringflowstr+"."+stormradstr+"."+sprintf("%03.0f",fhr)
text_output_file = output_file + ".txt"

; If output PNG and text file exist already and force_new=False, exit.
print("output_file: "+output_file+".png")
if(fileexists(output_file+".png").and.fileexists(text_output_file).and.force_new.eq.False)then
	print(output_file+".png and "+text_output_file+" exist already. Skipping")
	exit
end if

nc_output_file = output_file + ".nc"
if(nc_output)
	remove_storm_res@ofile = nc_output_file
end if





print("opening "+file_ncl)
ff = addfile(file_ncl,"r")
print("done")

isECMWF = .not.ismissing(str_match(file_ncl,"ECMWF"))
isWRF = .not.ismissing(str_match(ensmember,"WRF")).or..not.ismissing(str_match(file_ncl,"met_em.d")).or..not.ismissing(str_match(file_ncl,"wrfout_d"))
; Actual GFS ensemble forecast--not WRF forecasts initialized with gefs or GFS forecast
; from /glade/p/rda/data/ds084.1/2016/20160827/gfs.0p25.2016082700.f000.grib2
isGFS = str_get_cols(ensmember,0,2).eq."gep".or.str_get_cols(ensmember,0,2).eq."GFS".or.str_get_cols(ensmember,0,1).eq."AP".or.str_get_cols(ensmember,0,4).eq."AC00."
isNARR = isfilevar(ff,"gridlon_221").and.isfilevaratt(ff,"gridlon_221","grid_description").and.ff->gridlon_221@grid_description.eq."AWIPS - Regional - NOAMHI - High Resolution North American Master Grid (Lambert Conformal)"

print("getting 'init' (initialization time), lat2d and lon2d (2 dimensional latitude and longitude arrays)")

; In one of these if-blocks define
; u        - zonal wind on pressure levels
; v        - merid wind on pressure levels
; lev_ISBL - name of vertical dimension
; init     - numeric initialization time
; lat2d    - 2-D array of latitudes
; lon2d    - 2-D array of longitudes
; nlat     - length of N-S dim
; nlon     - length of E-W dim
; pbot_nd  - 2-D array of pressures on the bottom level

if(isNARR)then
    print("assuming NARR from /glade/collections/rda/data/ds608.0/3HRLY/")
	u = ff->U_GRD_221_ISBL
	v = ff->V_GRD_221_ISBL
	lv_ISBL = u!0
	format = "%N/%D/%Y (%H:%M)"
    format@units = "hours since 1970-01-01 00:00:00" 
	init = cd_inv_string(u@initial_time, format)
	lat2d = ff->gridlat_221
	lon2d = ff->gridlon_221
    tmp := dimsizes(ff->gridlon_221)
    nlat = tmp(0) 
    nlon = tmp(1) 
    pbot_nd := new((/1, nlat, nlon /), double)
    pbot_nd = pbot
end if
if(isECMWF)then
    print("assuming ECMWF forecasts downloaded from TIGGE and concatenated over forecast time")
	u = ff->u_P0_L100_GLL0
	v = ff->v_P0_L100_GLL0
	lv_ISBL = u!1
	format = "%N/%D/%Y (%H:%M)"
    format@units = "hours since 1970-01-01 00:00:00" 
	init = cd_inv_string(u@initial_time,format)
	tmp := u(0,0,:,:)
	lat2d = conform(tmp,u&lat_0,0)
	lon2d = conform(tmp,u&lon_0,1)
	copy_VarCoords(tmp,lat2d)
	copy_VarCoords(tmp,lon2d)

	; I'm leery of this fhr coordinate variable subscripting. Even when I request a fhr that is not in forecast_time0, it 
	; returns something and doesn't produce an error. It seems to pull out the closest hour less than requested one.
	u := u({forecast_time0|fhr},lv_ISBL0|:,lat_0|:,lon_0|:)
	v := v({forecast_time0|fhr},lv_ISBL0|:,lat_0|:,lon_0|:)
    pbot_nd := new((/1,dimsizes(u&lat_0),dimsizes(u&lon_0)/), double)
    pbot_nd = pbot
end if

if(isWRF)then
	; WRF forecasts or ECMWF analysis
	Times = tostring(ff->Times)
    print(Times)
	init = cd_inv_string(Times,"")
	; if you get errors about subscript out of range, fhr probably needs to be 0.
	; wrf_out files are just 1 time at a time.
	if(dimsizes(Times).eq.1)then
		fhr = 0
	end if
	lat2d = wrf_user_getvar(ff,"lat",fhr)
	lon2d = wrf_user_getvar(ff,"lon",fhr)

	; this is hybrid coordinates, so it must be handled differently than constant pressure level output.
	hyai = ff->hyai ; read from a file the interface hybrid coefficients
	hybi = ff->hybi ; read from a file
	ps   = ff->PS   ; surface pressure [Pa]
	p0   = 100000. ; since ps is in Pa 

	dp = dpres_hybrid_ccm(ps, p0, hyai, hybi)
	uvm = wrf_user_getvar(ff,"uvmet",fhr)
	u = uvm(0,:,:,:)
	v = uvm(1,:,:,:)
	lv_ISBL = u!1
	; Where do ptop and pbot go?
	print("Didn't adapt for WRF yet.")
	exit
end if
if(isGFS)then
	if(isfilevar(ff,"UGRD_P0_L100_GLL0"))then
		ustr = "UGRD_P0_L100_GLL0"
		vstr = "VGRD_P0_L100_GLL0"
	end if
	if(isfilevar(ff,"UGRD_P1_L100_GLL0"))then
		ustr = "UGRD_P1_L100_GLL0"
		vstr = "VGRD_P1_L100_GLL0"
	end if
	u = ff->$ustr$
	v = ff->$vstr$
	lv_ISBL = u!0
	lev = ff->$lv_ISBL$ ; needed below
	format = "%N/%D/%Y (%H:%M)"
    format@units = "hours since 1970-01-01 00:00:00" 
	init = cd_inv_string(u@initial_time, format)
	;Times = cd_string(valid, "%Y-%N-%D_%H:%M:%S")
	; Make sure we opened the correct grib file with the requested forecast time.
	if(u@forecast_time.ne.fhr)then
		print("requested forecast hour doesn't match forecast_time attribute in u")
		print(fhr)
		printVarSummary(u)
		exit
	end if
	tmp := u(0,:,:)
	lat2d = conform(tmp,u&lat_0,0)
	lon2d = conform(tmp,u&lon_0,1)
	copy_VarCoords(tmp,lat2d)
	copy_VarCoords(tmp,lon2d)
    pbot_nd := new((/1,dimsizes(u&lat_0),dimsizes(u&lon_0)/), double)
    pbot_nd = pbot
end if

print("done")
valid = init + fhr
; Copy time attributes from "init" to "valid"
copy_VarMeta(init,valid)
wks = gsn_open_wks("png",output_file)

lev = ff->$lv_ISBL$ ; needed below
if(lev@units.eq."hPa".or.lev@units.eq."mb")then
    lev = lev*100
    lev@units = "Pa"
end if
dp = dpres_plevel_Wrap(lev, pbot_nd*100, ptop*100, 0)
itime = 0
print("lev="+lev+" dp="+dp(itime,:,0,0))

; Sanity check. Make sure I agree with NCL's dp
dp_ahij = dp
kflag = 0
ier = 0
iopt=0
AHIJ::xdpresplvl(dimsizes(lev),todouble(lev),1,nlat,nlon,pbot_nd*100,getVarFillValue(lev), ptop*100, dp_ahij, iopt,kflag,ier)
print("lev="+lev+" dp="+dp_ahij(itime,:,0,0))
if(any((dp_ahij-dp).ne.0))then
    print("ahij got different dp")
    dp = dp_ahij
end if


version = systemfunc("ncl -V")
;sanity_check = addfile(version+".nc","c")
;sanity_check->dp = dp

; Get U/V at top and bottom to calculate environmental shear
utop = int2p_n_Wrap(lev, u, ptop*100, 1, 0) ; honestly don't know if linear or log is better (I think linear for wind; log for temperature)
vtop = int2p_n_Wrap(lev, v, ptop*100, 1, 0)
ubot = int2p_n_Wrap(lev, u, pbot*100, 1, 0)
vbot = int2p_n_Wrap(lev, v, pbot*100, 1, 0)

dp@steering_flow_bounds = steeringflowstr
dp@original_lev = (/ lev /)
; Refer to my copy of function. It wraps metadata and allows missing values. 6.4.0 does not.
u := wgt_vertical_n_Wrap(u, dp(itime,:,:,:), 0, 0)
v_old = v
v := wgt_vertical_n_Wrap(v, dp(itime,:,:,:), 0, 0)
if(isvar("wgt_vertical_n"))then
    v_SanityCheck := wgt_vertical_n(v_old, dp(itime,:,:,:), 0, 0)
    tmp := v - v_SanityCheck
    if(any(tmp.ne.0.))then
        printMinMax(v_old,False)
        printMinMax(v_SanityCheck,False)
        print("wgt_vertical_n_Wrap and wgt_vertical_n give different results")
        exit
    end if
end if

; Only needed for remove_storm.ncl and 2d lat/lon arrays. Tried putting in if(isNARR) and if(isWRF) blocks above but u loses metadata between there and here.  
if(isWRF.or.isNARR)then
	u@lat2d    = lat2d
	utop@lat2d = lat2d
	ubot@lat2d = lat2d
	u@lon2d    = lon2d
	utop@lon2d = lon2d
	ubot@lon2d = lon2d
end if

; Remove storm from forecast
; storm is at different places in different models and different forecast hours.
; Instead of eyeballing and defining lat/lon manually, use a-deck from GEFS
if(.not.ismissing(str_match(file_ncl,"WRFV3")))then
	print("reading WRF track "+modeltrack)
	adeck = read_wrf_track(modeltrack,init,3)
else
	print("reading ATCF "+modeltrack)
	adeck = read_atcf(modeltrack)
end if
adeck_valid = adeck@valid
adeck_valid@units = adeck@timeunits
; make sure valid and adeck_valid have the same time units before comparing.
valid = cd_convert(valid,adeck_valid@units)
i := ind(adeck_valid .eq. valid .and. adeck@rad .le. 34) ; changed from .eq. to .le. to catch rad=0. untested
if (dimsizes(i).ne.1.or.ismissing(i))then
	print("no valid time "+cd_string(valid,"")+" in "+modeltrack)
	print(cd_string(adeck_valid,""))
	exit
end if
lon0 = adeck@lon(i)
lat0 = adeck@lat(i)

if(remove_storm_res)then
	if(ismissing(lon0).or.ismissing(lat0))then
		print("storm lat or lon is missing. Can't continue")
		exit
	end if
	print("removing storm from "+tostring(lat0)+"N "+tostring(lon0)+"E")
	print("calculating environmental shear")
    shear_res = remove_storm_res
    shear_res@ofile = "" ; don't output netcdf files for top and bottom of env. shear layer.
    print("removing storm at "+sprinti("%d",ptop))
	UVtop = remove_storm(utop(0,:,:), vtop(0,:,:), lat0, lon0, shear_res)
    print("removing storm at "+sprinti("%d",pbot))
	UVbot = remove_storm(ubot(0,:,:), vbot(0,:,:), lat0, lon0, shear_res)
    print(sprintf("%3.1f",rx)+"deg "+tostring(pbot)+" "+tostring(ptop))
	shrU = UVtop@U-UVbot@U
	shrV = UVtop@V-UVbot@V
	SHRspeed = sqrt(shrU^2 + shrV^2)
	SHRheading = wind_direction(-shrU, -shrV,0)
	UV = remove_storm(u, v, lat0, lon0, remove_storm_res)
	u = (/UV(0,:,:)/)
	v = (/UV(1,:,:)/)
	SFheading = wind_direction(-UV@U, -UV@V,0)
	SFspeed = sqrt(UV@U^2 + UV@V^2)
        print("Steering flow U, V = "+sprintf("%5.2f, ",UV@U)+sprintf("%5.2f",UV@V)+sprintf(" mag=%5.2f",SFspeed))
	dheading = wind_direction(adeck@U(i)-UV@U,adeck@V(i)-UV@V,0)
	dspeed = sqrt((adeck@U(i)-UV@U)^2.+(adeck@V(i)-UV@V)^2.)
	dU = adeck@U(i)-UV@U ; movement minus steering flow
	dV = adeck@V(i)-UV@V
end if
fp := sqrt(u^2+v^2) 
copy_VarMeta(u,fp)
fp@long_name = "Wind speed"
;SET RESOURCES:
res := get_field_res(wks, "speedms", fp)
res = set_res_mp(res, stormname)
res@mpGridAndLimbOn = True
res@mpGridLineDashPattern = "Dot"
res@mpGridLineThicknessF = 1.5
res@gsnMajorLatSpacing = res@mpGridSpacingF
res@gsnMajorLonSpacing = res@mpGridSpacingF
res@tiMainString = stormname+sprintf(" %.0f",fhr) + " h fcst~C~"+str_get_cols(file_ncl,-41,-1)
res@tiMainFontHeightF = 0.022
;res@cnFillOpacityF = 0.8 ; affects color table but not filled contours
;printVarSummary(fp)
printMinMax(fp,False)
plot = gsn_csm_contour_map(wks,fp,res)

print("plotting "+track_files)
rxs = (/0., rx/)
rxs@label = True
tmp := plot_tracks(wks,plot,valid,track_files, rxs,(/"black","red"/))
print("done plotting tracks")

; Cosmetic changes for wind barbs
vres = True
vres@gsnDraw = False
vres@gsnFrame = False
vres@vcRefLengthF    = 0.03
vres@vcRefMagnitudeF    = 10.
vres@vcMinDistanceF = 0.03
vres@vcGlyphStyle = "LineArrow"
vres@vcLineArrowThicknessF = 2.
vres@vcLineArrowColor = "DarkSlateGray"
vres@vcRefAnnoOn = True
vres@vcRefAnnoSide = "Bottom"
vres@vcRefAnnoJust = "BottomRight"
vres@vcRefAnnoOrthogonalPosF = -0.05
vres@vcRefAnnoString1 = "$VMG$ " + fp@units
vres@vcRefAnnoZone = 1

vres@gsnLeftString = "Wind vectors"

if(isatt(fp,"units"))then
	if(fp@units.eq."kt")then
		vres@gsnLeftString = vres@vcGlyphStyle
		vres@gsnRightString = "kt"
	end if
end if
print("making wind vectors")
plot_ov := gsn_csm_vector(wks,u,v,vres)
print("overlaying wind vectors")
overlay(plot,plot_ov)

print("drawing plot")
draw(plot)

txres := True
txres@txFontHeightF = 0.016
txres@txJust = "TopLeft"
; str = sprintf("%7.1f~S~o~N~N",lat0)+", "+sprintf("%5.1f~S~o~N~E",lon0))
str = "storm radius:~C~     "+stormradstr+"~C~layer: "+steeringflowstr+\
      "~C~~C~env shear hdg:~C~     "+sprintf("%3.0f~S~o~N~",SHRheading)+" @ "+sprintf("%.1fm s~S~-1~N~",SHRspeed)+\
      "~C~~C~storm movement:~C~     "+sprintf("%3.0f~S~o~N~",adeck@heading(i))+" @ "+sprintf("%.1fm s~S~-1~N~",adeck@speed(i))+\
      "~C~steering flow hdg:~C~     "+sprintf("%3.0f~S~o~N~",SFheading)+" @ "+sprintf("%.1fm s~S~-1~N~",SFspeed)+\
      "~C~~C~storm movement -~C~    steering flow"+\
      "~C~dU, dV: "+sprintf("%4.1f,",dU) + sprintf("%5.1f",dV) + sprintf("~C~    (%.1fm s~S~-1~N~)",sqrt(dU^2.+dV^2.))
gsn_text_ndc(wks, str, 0.78, 0.63, txres)
print(str)
write_table(text_output_file, "w", [/ ensmember, fhr, tofloat(pbot), tofloat(ptop), tofloat(rx), SHRheading, SHRspeed, adeck@heading(i), adeck@speed(i), SFheading, SFspeed, dU, dV, sqrt(dU^2.+dV^2.) /], "%20s%5d%8.1f%8.1f%5.2f%8.2f%8.3f%8.2f%8.3f%8.2f%8.3f%8.3f%8.3f%8.3f")

ts = systemfunc("date")
ts = "track files: "+str_join(track_files,", ")+\
      "~C~available levels: " + str_join(sprintf("%.0fmb",lev/100),", ")+\
      "~C~created "+ts+" ncl/"+version
txres@txJust = "BottomLeft"
if(isatt(adeck,"plus_minus_hrs"))then
	ts = "storm movement over centered "+tostring(2*adeck@plus_minus_hrs)+"h window~C~"+ts
end if
txres@txFontHeightF = 0.009
gsn_text_ndc(wks, ts, 0.09, 0.0005, txres)

; If "dlat" and "dlon" are pre-defined, figure out the grid coordinates and pull out 
; u and v (the model steering flow) at that point. Can't remember why. 
if(isvar("dlat").and.isvar("dlon"))then
	dropres = True
	dropres@gsMarkerSizeF = 12.
	dropres@gsMarkerThicknessF = 6.
	gsn_polymarker(wks,plot,dlon,dlat,dropres)
	tmp := getind_latlon2d(lat2d,lon2d,dlat,dlon)
	n := tmp(0,0)
	m := tmp(0,1)
	dropU = u(n,m)
	dropV = v(n,m)
	str = "lat/lon: "+sprintf("%5.2fN",dlat)+"/"+sprintf("%6.2fE",dlon)+"~C~U/V: "+sprintf("%6.2f",dropU)+"/"+sprintf("%6.2f",dropV)+dropU@units
	gsn_text_ndc(wks, str, 0.56, 0.06, txres)
	gsn_polymarker_ndc(wks, 0.55, 0.06, dropres)
end if 
frame(wks)
print("processing success "+output_file+".png")
end

;=============================================================================================
