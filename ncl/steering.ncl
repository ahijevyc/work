;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"
; Temporarily refer to my copy of wgt_vertical_n until 6.4.0 beta is released.
load "/glade/p/work/ahijevyc/ncl/wgt_vertical_n.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/remove_storm.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"

;=============================================================================================

begin

; Analyze steering flow around storm
; Reads:
; 	WRF initialized with GFS or GEFS
;	ECMWF analysis (ECMWFa.2015093000 ECMWFa.2015093006)
;	ECMWF TIGGE forecasts (EMX.2015093000 EMX.2015093012)
;	GFS from /glade/p/rda/data/ds084.1/2016/20160827/gfs.0p25.2016*
;
; Input:
;	ensmember: basename of file with storm track (in same directory as execution directory)
;	rx : radius of storm in degrees (default 4.)
;	fhr : forecast hour (default 48)
;	file_ncl: file to process
;	ptop: top pressure level in hPa (default 250.)
;	pbot: bottom pressure level in hPa (default 850.)
;
; Output:
;	PNG
;	netCDF: steering_ofile.nc (defined by res@ofile)




if(.not.isvar("fhr")) then
	fhr= 48
end if
if(.not.isvar("ensmember")) then
	ensmember = "gep20.2015093000" ; for actual gefs forecast, not WRF init'd with it.
	ensmember = "ECMWFa.2015093000"
	ensmember = "GFSO"
end if
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
		file_ncl="/glade/scratch/weiwang/v371/WPS/ec/met_em.d01."+cd_string(cd_inv_string(date),"%Y-%N-%D_%H:%M:%S")+".nc"
	end if
end if
if(.not.isvar("rx")) then 
	rx = 4.
end if
remove_storm_res = True
remove_storm_res@units = "degrees"
remove_storm_res@rx = tofloat(rx)
remove_storm_res@ofile = "steering_ofile.nc"

print("opening "+file_ncl)
ff = addfile(file_ncl,"r")

; get "init" (initialization time), lat2d and lon2d (2 dimensional latitude and longitude arrays)
if(.not.ismissing(str_match(file_ncl,"ECMWF")))then
	; ECMWF forecasts downloaded from TIGGE and concatenated over forecast time
	u = ff->u_P1_L100_GLL0
	v = ff->v_P1_L100_GLL0
	init = cd_inv_string(u@initial_time)
	tmp := u(0,0,:,:)
	lat2d = conform(tmp,u&lat_0,0)
	lon2d = conform(tmp,u&lon_0,1)
	copy_VarCoords(tmp,lat2d)
	copy_VarCoords(tmp,lon2d)
	Times = sprintf("%03.0f",fhr)
end if
isWRF = .not.ismissing(str_match(ensmember,"WRF")).or..not.ismissing(str_match(file_ncl,"met_em.d")).or..not.ismissing(str_match(file_ncl,"wrfout_d"))
if(isWRF)then
	; WRF forecasts or ECMWF analysis
	Times = tostring(ff->Times)
	init = cd_inv_string(Times)
	ifhr = fhr
	; if you get errors about subscript out of range, fhr probably needs to be 0.
	; wrf_out files are just 1 time at a time.
	if(dimsizes(Times).eq.1)then
		ifhr = 0
	end if
	lat2d = wrf_user_getvar(ff,"lat",ifhr)
	lon2d = wrf_user_getvar(ff,"lon",ifhr)
end if
if(str_get_cols(ensmember,0,3).eq."GFSO")then
	; GFS forecast from /glade/p/rda/data/ds084.1/2016/20160827/gfs.0p25.2016082700.f000.grib2
	ustr = "UGRD_P0_L100_GLL0"
	vstr = "VGRD_P0_L100_GLL0"
end if
if(str_get_cols(ensmember,0,2).eq."gep")then
	; Actual GFS ensemble forecast not WRF forecasts initialized with gefs
	ustr = "UGRD_P1_L100_GLL0"
	vstr = "VGRD_P1_L100_GLL0"
end if
if(str_get_cols(ensmember,0,2).eq."gep".or.str_get_cols(ensmember,0,3).eq."GFSO")then
	u = ff->$ustr$
	v = ff->$vstr$
	init = cd_inv_string(u@initial_time)
	;Times = cd_string(valid, "%Y-%N-%D_%H:%M:%S")
	Times = sprintf("%03.0f",fhr)
	tmp := u(0,:,:)
	lat2d = conform(tmp,u&lat_0,0)
	lon2d = conform(tmp,u&lon_0,1)
	copy_VarCoords(tmp,lat2d)
	copy_VarCoords(tmp,lon2d)
end if
valid = init + fhr
; Copy time attributes from "init" to "valid"
copy_VarMeta(init,valid)

if(.not.isvar("pbot")) then
	pbot = 850.
end if
if(.not.isvar("ptop")) then
	ptop = 250.
end if
steeringflowstr = sprintf("%.0f",pbot)+"-"+sprintf("%.0f",ptop)+"hPa"
stormradstr = sprintf("%.1f",remove_storm_res@rx)+remove_storm_res@units
output_file = ensmember+"."+steeringflowstr+"."+stormradstr+"."+Times
wks = gsn_open_wks("png",output_file)

if(isWRF)then
	; this is hybrid coordinates, so it must be handled differently than constant pressure level output.
	hyai = ff->hyai ; read from a file the interface hybrid coefficients
	hybi = ff->hybi ; read from a file
	ps   = ff->PS   ; surface pressure [Pa]
	p0   = 100000. ; since ps is in Pa 

	dp = dpres_hybrid_ccm(ps, p0, hyai, hybi)
	uvm = wrf_user_getvar(ff,"uvmet",ifhr)
	u = uvm(0,:,:,:)
	v = uvm(1,:,:,:)
end if
if(.not.ismissing(str_match(file_ncl,"ECMWF")))then
	; ECMWF
	; I'm leery of this fhr coordinate variable subscripting. Even when I request a fhr that is not in forecast_time0, it 
	; returns something and doesn't produce an error. It seems to pull out the closest hour less than requested one.
	u := u({forecast_time0|fhr},lv_ISBL0|:,lat_0|:,lon_0|:)
	v := v({forecast_time0|fhr},lv_ISBL0|:,lat_0|:,lon_0|:)
	pbot_2d := new((/dimsizes(u&lat_0),dimsizes(u&lon_0)/), float)
	pbot_2d = pbot
	lev = ff->lv_ISBL0
	dp = dpres_plevel_Wrap(lev, pbot_2d*100, ptop*100, 0)
end if
if(str_get_cols(ensmember,0,2).eq."gep".or.str_get_cols(ensmember,0,3).eq."GFSO")then
	pbot_2d := new((/dimsizes(u&lat_0),dimsizes(u&lon_0)/), float)
	pbot_2d = pbot
	lev = ff->lv_ISBL0
	dp = dpres_plevel_Wrap(lev, pbot_2d*100, ptop*100, 0)
end if

dp@steering_flow_bounds = steeringflowstr
; Temporarily refer to my copy of function until 6.4.0 beta is released.
u := wgt_vertical_n(u, dp, 0, 0)
v := wgt_vertical_n(v, dp, 0, 0)

; Only needed for remove_storm.ncl and WRF. 
if(isWRF)then
	u@lat2d = lat2d
	u@lon2d = lon2d
end if

circlat = new(100,float)
circlon = new(100,float)

; Remove storm from forecast
; storm is at different places in different models and different forecast hours.
; Instead of eyeballing and defining lat/lon manually, use a-deck from GEFS
if(.not.ismissing(str_match(file_ncl,"WRFV3")))then
	track_file = "WRF."+ensmember
	print("reading WRF track "+track_file)
	adeck = read_wrf_track(track_file,init,3)
else
	track_file = ensmember
	print("reading ATCF "+track_file)
	adeck = read_atcf(track_file)
end if
i := ind(adeck@valid .eq. valid .and. adeck@rad .eq. 34)
if (dimsizes(i).ne.1.or.ismissing(i))then
	print("no valid time "+valid+" in "+track_file)
	print(adeck@valid)
	exit
end if
lon0 = adeck@lon(i)
lat0 = adeck@lat(i)

if(remove_storm_res)then
	if(ismissing(lon0).or.ismissing(lat0))then
		print("storm lat or lon is missing. Can't continue")
		exit
	end if
	nggcog(lat0,lon0,remove_storm_res@rx,circlat,circlon)
	print("removing storm from "+tostring(lat0)+"N "+tostring(lon0)+"E")
	tmp := remove_storm(u, v, lat0, lon0, remove_storm_res)
	u = (/tmp(0,:,:)/)
	v = (/tmp(1,:,:)/)
        print(tostring(rx)+"deg "+tostring(pbot)+" "+tostring(ptop)+" steering flow U, V = "+sprintf("%5.2f, ",tmp@U)+sprintf("%5.2f",tmp@V))
	SFheading = wind_direction(-tmp@U, -tmp@V,0)
	SFspeed = sqrt(tmp@U^2 + tmp@V^2)
	dheading = wind_direction(adeck@U(i)-tmp@U,adeck@V(i)-tmp@V,0)
	dspeed = sqrt((adeck@U(i)-tmp@U)^2.+(adeck@V(i)-tmp@V)^2.)
	dU = adeck@U(i)-tmp@U
	dV = adeck@V(i)-tmp@V
end if
fp := sqrt(u^2+v^2) 
copy_VarMeta(u,fp)
;SET RESOURCES:
res := get_field_res(wks, "speedms", fp)
res = set_res_mp(res, "Lionrock")
res@mpGridAndLimbOn = True
res@mpGridLineDashPattern = "Dot"
res@mpGridLineThicknessF = 3.
res@gsnMajorLatSpacing = res@mpGridSpacingF
res@gsnMajorLonSpacing = res@mpGridSpacingF
res@tiMainString = str_get_cols(file_ncl,-40,-1)+ " " + sprintf("%.0f",fhr) + " h fcst"
res@tiMainFontHeightF = 0.022
;printVarSummary(fp)
printMinMax(fp,False)
plot = gsn_csm_contour_map(wks,fp,res)


track_files = (/ "/glade/p/work/ahijevyc/ECMWF/Lionrock/ECMWF.2016082700", "/glade/p/work/ahijevyc/GFS/Lionrock/GFSO.2016082700" /)

tmp := plot_tracks(wks,plot,valid,track_files,rx,(/"black","red"/))

; Cosmetic changes for wind barbs
vres = True
vres@gsnDraw = False
vres@gsnFrame = False
vres@vcRefLengthF    = 0.03
vres@vcRefMagnitudeF    = 10.
vres@vcMinDistanceF = 0.03
vres@vcGlyphStyle = "LineArrow"
vres@vcLineArrowThicknessF = 2.
vres@vcRefAnnoOn = True
vres@gsnLeftString = "Wind vectors"

if(isatt(fp,"units"))then
	if(fp@units.eq."kt")then
		vres@gsnLeftString = vres@vcGlyphStyle
		vres@gsnRightString = "kt"
	end if
end if
plot_ov := gsn_csm_vector(wks,u,v,vres)
overlay(plot,plot_ov)

draw(plot)

str = "storm size: "+stormradstr+"~C~steering flow: "+steeringflowstr
txres := True
txres@txFontHeightF = 0.016
gsn_text_ndc(wks, str, 0.55, 0.8, txres)
txres@txFontHeightF = 0.01
; str = sprintf("%7.1f~S~o~N~N",lat0)+", "+sprintf("%5.1f~S~o~N~E",lon0))
str = "   storm movement "+sprintf("%3.0f~S~o~N~",adeck@heading(i))+" @ "+sprintf("%.1fm s~S~-1~N~",adeck@speed(i))+\
      "~C~steering "+sprintf("%3.0f~S~o~N~",SFheading)+" @ "+sprintf("%.1fm s~S~-1~N~",SFspeed)+\
      "~C~dU, dV: "+sprintf("%4.1f,",dU)+sprintf("%5.1fm s~S~-1~N~",dV)
txres@txJust = "TopLeft"
gsn_text(wks, plot, str, lon0, lat0, txres)

ts = systemfunc("date")
ts = "track files: "+str_join(track_files,"~C~")+"~C~created "+ts
txres@txJust = "BottomLeft"
if(isatt(adeck,"spdhed_plusminust"))then
	ts = "displacement over centered "+tostring(2*adeck@spdhed_plusminust)+"h window~C~"+ts
end if
gsn_text_ndc(wks, ts, 0.1, 0., txres)

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
