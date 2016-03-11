;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/remove_storm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
;=============================================================================================

; compare GFS forecast to ECMWF analysis
; or compare ECMWF forecast to ECMWF analysis (file_ncl="/glade/scratch/ahijevyc/ECMWF/...grb")
; or compare GFS analysis to ECMWF analysis (fhr=0)

; use get_gfs.csh to obtain GFS files, but remember to concatenate them. No separate forecast files. This script assumes that.

begin
if(.not.isvar("date")) then
	date = "2015093012"
end if
ymd=str_get_cols(date,0,7)
hhmm=str_get_cols(date,8,9)+"00"

if(.not.isvar("field")) then 
	;field = "ttr_P11_L8_GLL0_acc" ; cumulative olrtoa
	;field = "vorticity_500hPa"
	;field = "u_P1_L100_GLL0"
	field = "tp_P11_L1_GLL0_acc"
	;field = "APCP_P8_L1_GLL0_acc6h"
	;field = "ACPCP_P8_L1_GLL0_acc6h"
	;field = "PRATE_P8_L1_GLL0_avg6h"
	;field = "difference field for wind speed"
end if
if(.not.isvar("fhr")) then 
	fhr = 36 
end if
if(.not.isvar("hPa")) then 
	hPa = 500
end if
if(.not.isvar("file_ncl")) then 
	file_ncl = "/glade/scratch/ahijevyc/GFS/"+date+"/gfdl_tracker/gfs_4_"+ymd+"_"+hhmm+".grb2"
	;file_ncl = "/glade/scratch/ahijevyc/ECMWF/"+date+"/"+date+".grb"
end if
if(.not.isvar("rm_storm_deg")) then 
	rm_storm_deg = 0.
end if
output_file = "./"+field
wks = gsn_open_wks("png",output_file)

ff = addfile(file_ncl,"r")
;print(ff)
forecast_time = fhr
plvlPa = hPa * 100

varnames = getfilevarnames(ff)
uvar = str_match_ic_regex(varnames, "U.*_L100_GLL0")
vvar = str_match_ic_regex(varnames, "V.*_L100_GLL0")
;print(varnames)
contour_string = str_match_ic_regex(varnames, "((HGT)|(gh))_P[01]_L100_GLL0")
if(field.eq."tp_P11_L1_GLL0_acc".or.field.eq."APCP_P8_L1_GLL0_acc6h".or.field.eq."ACPCP_P8_L1_GLL0_acc6h".or.field.eq."PRATE_P8_L1_GLL0_avg6h")then
	; MSLP contours msl_P1_L101_GLL0
	contour_string = str_match_ic_regex(varnames, "(PR)?msl_P[01]_L101_GLL0")
	printVarSummary(ff->$contour_string$)
	cntr = ff->$contour_string$({forecast_time0|forecast_time},lat_0|:,lon_0|:)
else
	cntr = ff->$contour_string$({forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|:,lon_0|:)
end if
;print(uvar)
;print(contour_string)

ntime = 1
if(isfilevardim(ff, uvar, "initial_time0_hours"))then
	ntime = getfilevardimsizes(ff, "initial_time0_hours")
end if

circlat = new(100,float)
circlon = new(100,float)
acirclat = new(100,float)
acirclon = new(100,float)

do itime = 0, ntime-1,2

	if(isfilevardim(ff, uvar, "initial_time0_hours"))then
		valid = initial_time0_hours(itime)
	else
		valid = ff->$uvar$@initial_time
		month = toint(str_get_cols(valid,0,1))
		day = toint(str_get_cols(valid,3,4))
		year = toint(str_get_cols(valid,6,9))
		hour = toint(str_get_cols(valid,12,13))
		minute = toint(str_get_cols(valid,15,16))
		valid := cd_inv_calendar(year,month,day,hour,minute,0,"hours since 1800-01-01 00:00",0)
	end if
	valid = valid + forecast_time

	; Figure out analysis file to overlay.
	analysis_file = cd_string(valid,"/glade/scratch/ahijevyc/ECMWF/%Y%N%D%H/%Y%N%D%H.grb")
	analysis = addfile(analysis_file, "r")
	varnames := getfilevarnames(analysis)
	auvar = str_match_ic_regex(varnames, "U.*_L100_GLL0")
	avvar = str_match_ic_regex(varnames, "V.*_L100_GLL0")
	acontour_string = str_match_ic_regex(varnames, "gh_P1_L100_GLL0")

	if(str_get_cols(field,0,3).eq."vort".or.field.eq."difference field for wind speed")then
		; Read u and v. Flip latitude coordinate so it ascends.
		if(isfilevardim(ff, uvar, "initial_time0_hours"))then
			u = ff->$uvar$(initial_time0_hours|itime,{forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
			v = ff->$vvar$(initial_time0_hours|itime,{forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
		else
			u = ff->$uvar$({forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
			v = ff->$vvar$({forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
		end if
		; Remove storm from forecast
		; storm is at different places in different models and different forecast hours.
		if(.not.ismissing(str_match(file_ncl,"GFS")))
			lat0=25.2 ; 24h GFS
			lon0=360-73.1 ; 24h GFS
		end if
		if(.not.ismissing(str_match(file_ncl,"ECMWF")))
			lat0=24.0 ; 0h ECMWF adeck
			lon0=360-73.0 ; 0h ECMWF adeck
			if(fhr.eq.24)then
				lat0=24.3 ; 24 ECMWF adeck
				lon0=360-73.1 ; 24 ECMWF adeck
			end if
		end if
		nggcog(lat0,lon0,rm_storm_deg,circlat,circlon)
		tmp := remove_storm(u, v, lat0, lon0, rm_storm_deg)
		u = tmp(0,:,:)
		v = tmp(1,:,:)
		if(field.eq."difference field for wind speed")then
			u0 = analysis->$auvar$({forecast_time0|0},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
			v0 = analysis->$avvar$({forecast_time0|0},{lv_ISBL0|plvlPa},lat_0|::-1,lon_0|:)
			; Remove storm from Analysis
			lat0=24.0 ; 0h ECMWF adeck
			lon0=360-73.0 ; 0h ECMWF adeck
			nggcog(lat0,lon0,rm_storm_deg,acirclat,acirclon)
			tmp := remove_storm(u0, v0, lat0, lon0, rm_storm_deg)
			u0 = tmp(0,:,:)
			v0 = tmp(1,:,:)
			fp := sqrt(u^2+v^2) - sqrt(u0^2+v0^2)
			copy_VarMeta(u,fp)
		else
			; do vorticity
			fp := uv2vrF_Wrap(u,v)
		end if
	else if (field.eq."tp_P11_L1_GLL0_acc")then
		; accumulated rainfall
		fp := ff->$field$({forecast_time0|forecast_time},lat_0|:,lon_0|:)
		fp = fp - ff->$field$({forecast_time0|forecast_time-6},lat_0|:,lon_0|:)
	else if (field.eq."APCP_P8_L1_GLL0_acc6h".or.field.eq."ACPCP_P8_L1_GLL0_acc6h".or.field.eq."PRATE_P8_L1_GLL0_avg6h")then
		; accumulated rainfall
		fp := ff->$field$({forecast_time1|forecast_time},lat_0|:,lon_0|:)
	else
		if(isfilevardim(ff, field, "lv_ISBL0"))then
			fp := ff->$field$(initial_time0_hours|itime,{forecast_time0|forecast_time},{lv_ISBL0|plvlPa},lat_0|:,lon_0|:)
		else
			if(isfilevardim(ff, field, "initial_time0_hours"))then
				fp := ff->$field$(initial_time0_hours|itime,{forecast_time0|forecast_time},lat_0|:,lon_0|:)
			else
				fp := ff->$field$({forecast_time0|forecast_time},lat_0|:,lon_0|:)
			end if
		end if
	end if
	end if
	end if
	;SET RESOURCES:
	res := get_field_res(wks, field, fp)
	res = set_res_mp(res, "Joaquin")
	res@tiMainString = fp@center+"~C~"+sprintf("%.0f",fhr)+"h fcst valid "+cd_string(valid,"%Y-%N-%D_%H")+"~C~"+sprintf("%.0fhPa",plvlPa/100)
	;printVarSummary(fp)
	;printMinMax(fp,False)
	delete(res@LabelFontHeightF)
	plot = gsn_csm_contour_map(wks,fp,res)

	; Forecast Contours
	sres = get_res_cn("al",contour_string,cntr)
	sres@cnLineColor = "red"
	plot_ov := gsn_csm_contour(wks,cntr,sres)
	overlay(plot, plot_ov)
	;gsn_polyline(wks,plot,circlon,circlat,sres) ; removed storm within this circle

	; Cosmetic changes for wind barbs
	vres = True
	vres@gsnDraw = False
	vres@gsnFrame = False
	vres@vcRefLengthF    = 0.024
	vres@vcGlyphStyle = "WindBarb"
	vres@vcPositionMode = "ArrowHead"
	vres@vcMinDistanceF = 0.030
	vres@vcRefAnnoOn = True
	vres@vcRefAnnoSide = "Right"

	vres@vcWindBarbLineThicknessF = 1.6
	vres@vcWindBarbScaleFactorF = 1.94384
	vres@vcRefAnnoString1 = "full barb = 10 kt"
	vres@vcRefAnnoString2 = "pennant = 50 kt"
	vres@gsnLeftString = vres@vcGlyphStyle
	if(isvar("u0"))then
		; Analysis Contours
		cntr = analysis->$acontour_string$({forecast_time0|0},{lv_ISBL0|plvlPa},lat_0|:,lon_0|:)
		sres = get_res_cn("al",contour_string,cntr)
		sres@cnLineColor = "blue"
		sres@cnLineThicknessF = 4.
		sres@gsnLeftStringParallelPosF = 0.44
		plot_ov := gsn_csm_contour(wks,cntr,sres)
		overlay(plot, plot_ov)
		gsn_polyline(wks,plot,acirclon,acirclat,False) ; remove storm within this circle
		u = u - u0
		v = v - v0
		vres@gsnLeftString = "forecast - analysis wind barbs"
	end if
	vres@gsnRightString = "kt"
	vres@gsnLeftStringOrthogonalPosF = -0.041
	vres@gsnRightStringOrthogonalPosF = -0.041
	if(isvar("u"))then
		plot_ov := gsn_csm_vector(wks,u,v,vres)
		overlay(plot,plot_ov)
		if(isvar("u0"))then
			lat2d = conform(u,u&lat_0,0)
			lon2d = conform(u,u&lon_0,1)
			copy_VarCoords(u,lat2d)
			copy_VarCoords(u,lon2d)
			dist = gc_latlon(24.5, -73.1, lat2d, lon2d, 2, 2) ; last arg is units. 4=km; 2=degrees
			copy_VarCoords(u,dist)
			rxs = (/ rm_storm_deg /)
			do it=0,dimsizes(rxs)-1
				uavg = avg(mask(u,dist.lt.rxs(it),True))
				vavg = avg(mask(v,dist.lt.rxs(it),True))
				print(tostring(rxs(it))+"deg u="+tostring(uavg)+u@units+" v="+tostring(vavg)+v@units)
			end do
			sres@cnLineColor = "black"
			sres@cnLevelSelectionMode = "ExplicitLevels"
			sres@cnLevels = rxs
			sres@gsnRightString = ""
			sres@cnLineLabelFontHeightF = 0.013
			sres@cnExplicitLineLabelsOn = True
			sres@cnLineLabelStrings = (/ sprintf("%.0f "+dist@units, rxs) /)
			sres@cnInfoLabelOn = False
			plot_ov := gsn_csm_contour(wks, dist, sres)
			overlay(plot,plot_ov)
		end if
	end if
	
	draw(plot)
	frame(wks)
end do

print("processing success "+output_file+".png")
end

;=============================================================================================
