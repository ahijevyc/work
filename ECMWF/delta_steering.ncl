;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_inv_string.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"

;=============================================================================================
undef("aframe")
function aframe(wks, fp, valid, track_files, rxs)
begin
	res := get_field_res(wks, fp@long_name+"_"+fp@steering_flow_bounds, fp)
	stormname = str_split(track_files(1),"/")
	stormname := stormname(dimsizes(stormname)-2)
	;print("stormname="+stormname)
	res = set_res_mp(res, stormname)
	if(isatt(fp,"forecast_time0"))then
		fhr = tostring(fp@forecast_time0)
	end if
	if(isatt(fp,"forecast_time"))then
		fhr = tostring(fp@forecast_time)
	end if
	res@tiMainString = stormname + "~C~" + fp@center+" " + fhr +" h fcst"
	res@tiMainFontHeightF = 0.022
	if(isatt(res,"nSmoothPasses"))then
		delete(res@nSmoothPasses)
	end if
	plot = gsn_csm_contour_map(wks,fp,res)
	tmp := plot_tracks(wks,plot,valid,track_files, rxs, (/"black", "red", "blue"/))
	; Time stamp in lower left corner.
	ts = systemfunc("date")
	txres := True
	txres@txFontHeightF = 0.01
	txres@txJust = "BottomLeft"
	gsn_text_ndc(wks, "track files:"+str_join(track_files,"~C~")+"~C~created "+ts, 0., 0.0, txres)
	return(plot)
end

begin

stormname = "Matthew"
ecfile = "/glade/p/work/ahijevyc/ECMWF/"+stormname+"/EMX.2016092900.850-400hPa.1.5degrees.072.nc"
ec = addfile(ecfile,"r")
gffile = "/glade/p/work/ahijevyc/GFS/"  +stormname+"/GFS.2016092900.850-400hPa.1.5degrees.072.nc"
gf = addfile(gffile,"r")

u0 = ec->UR
v0 = ec->VR
rx0 = ec->rx
u  = gf->UR
v  = gf->VR
rx = gf->rx
format = "%N/%D/%Y (%H:%M)"
format@units = "hours since 1970-01-01 00:00:00" 
ECinit = cd_inv_string(u0@initial_time,format)
GFinit = cd_inv_string(u@initial_time,format)
if(ECinit.ne.GFinit)then
	print("Init times don't match "+ECinit+" "+GFinit)
	exit
end if
init = ECinit
ECfh = u0@forecast_time0
GFfh = u@forecast_time
if(ECfh.ne.GFfh)then
	print("forecast hours don't match")
	print(ECfh)
	print(GFfh)
	exit
end if
fhr = ECfh

valid = init + fhr
; Copy time attributes from "init" to "valid"
copy_VarMeta(init,valid)

stormradstr = sprintf("%.1f",rx0)+rx0@units
if(rx0.ne.rx)then
	print("radius of storm don't match")
	print(rx0)
	print(rx)
	stormradstr = sprintf("%.1f",rx)+rx@units + stormradstr
end if

steering_flow_bounds_str = u0@steering_flow_bounds
if(u0@steering_flow_bounds.ne.u@steering_flow_bounds)then
	print("environmental wind bounds don't match")
	print("ec = "+u0@steering_flow_bounds)
	print("gf = "+u@steering_flow_bounds)
	steering_flow_bounds_str = u@steering_flow_bounds + steering_flow_bounds_str ; GFS first
end if


if(stormname.eq."Joaquin")then
    sid = "al112015"
end if
if(stormname.eq."Lionrock")then
    sid = "wp122016"
end if
if(stormname.eq."Matthew")then
    sid = "al142016"
end if

track_files = (/ "/glade/p/work/ahijevyc/atcf/b"+sid+".dat", "/glade/p/work/ahijevyc/ECMWF/"+stormname+"/EMX.2016092900", "/glade/p/work/ahijevyc/GFS/"+stormname+"/GFS.2016092900" /)
rxs = (/0, rx0, rx/)
rxs@label = True ; label circle around storm with radius

; Cosmetic changes for wind barbs
vres = True
vres@gsnDraw = False
vres@gsnFrame = False
vres@vcRefLengthF    = 0.04
vres@vcRefMagnitudeF    = 20.
vres@vcMinDistanceF = 0.028
vres@vcLineArrowThicknessF = 2.
vres@vcLineArrowColor = "DarkSlateGray"
vres@vcRefAnnoOn = True
vres@vcRefAnnoSide = "Bottom"
vres@vcRefAnnoJust = "BottomRight"
vres@vcRefAnnoOrthogonalPosF = -0.05
vres@vcRefAnnoString1 = "$VMG$ " + u0@units
vres@vcRefAnnoZone = 1

vres@gsnLeftString = "Wind vectors"

; Time stamp in lower left corner.
ts = systemfunc("date")
time_stamp_res := True
time_stamp_res@txFontHeightF = 0.01
time_stamp_res@txJust = "BottomLeft"

output_file = "delta_EW.GFS-EMX."+steering_flow_bounds_str+"."+stormradstr+"."+sprinti("%03i",fhr)
wks = gsn_open_wks("png",output_file)

; ECMWF vorticity 
plot = aframe(wks, ec->vrt, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,ec->U,ec->V,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; ECMWF vorticity without storm
plot = aframe(wks, ec->vrtR, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,ec->UR,ec->VR,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; GFS vorticity
plot = aframe(wks, gf->vrt, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,gf->U,gf->V,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; GFS vorticity without storm
plot = aframe(wks, gf->vrtR, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,gf->UR,gf->VR,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)

; ECMWF divergence 
plot = aframe(wks, ec->div, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,ec->U,ec->V,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; ECMWF divergence without storm
plot = aframe(wks, ec->divR, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,ec->UR,ec->VR,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; GFS divergence
plot = aframe(wks, gf->div, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,gf->U,gf->V,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)
; GFS divergence without storm
plot = aframe(wks, gf->divR, valid, track_files, rxs)
plot_ov := gsn_csm_vector(wks,gf->UR,gf->VR,vres)
overlay(plot,plot_ov)
draw(plot)
frame(wks)


print("Done plotting winds with and without storm for ECMWF and GFS.")
print("Now plot difference in environmental wind.")



dU = u-u0
dV = v-v0
copy_VarMeta(u,dU)
copy_VarMeta(v,dV)
fp := sqrt(dU^2+dV^2) 
copy_VarMeta(u,fp)
fp@long_name = "Wind speed"
;SET RESOURCES:
res = get_field_res(wks, "speedms", fp)
res = set_res_mp(res, stormname)
res@tiMainString = stormname+" "+tostring(fhr)+" h fcst"+"~C~GFS - ECMWF EW difference"
;printVarSummary(fp)
;printMinMax(fp,False)
plot = gsn_csm_contour_map(wks,fp,res)


tmp := plot_tracks(wks,plot,valid,track_files, rxs, (/"black", "red", "blue"/))

; Wind barbs
vres@vcRefLengthF       = 0.045
vres@vcRefMagnitudeF    = 2.
plot_ov := gsn_csm_vector(wks,dU,dV,vres)
overlay(plot,plot_ov)

draw(plot)

txres := True
txres@txFontHeightF = 0.016
txres@txJust = "TopLeft"
str = "storm radius:~C~   "+stormradstr+"~C~layer:~C~   "+steering_flow_bounds_str+\
      "~C~~C~GFS EW U, V:~C~   "+sprintf("%4.1f,",gf->Uavg) + sprintf("%5.1f",gf->Vavg) + " " + gf->Uavg@units +\
      "~C~EMX EW U, V:~C~   "   +sprintf("%4.1f,",ec->Uavg) + sprintf("%5.1f",ec->Vavg) + " " + ec->Uavg@units
gsn_text_ndc(wks, str, 0.78, 0.63, txres)

; File info/Time stamp/version in lower left corner.
version = systemfunc("ncl -V")
gsn_text_ndc(wks, str_join(systemfunc("ls -l "+ecfile+" "+gffile),"~C~")+"~C~created "+ts+" ncl/"+version, 0., 0.0, time_stamp_res)

frame(wks)
print("processing success "+output_file+".png")
end

;=============================================================================================
