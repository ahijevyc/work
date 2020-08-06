;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;=============================================================================================

begin
if(.not.isvar("date")) then
 date = "2015080600"
end if

if(.not.isvar("field")) then 
	field = "UGRD_P0_L100_GLL0"
end if
diri = "/glade/p/work/ahijevyc/ncl/nggps/"+date+"/"
if(.not.isvar("VertLevel"))then
	VertLevel = 100.
end if
if(.not.isvar("file_ncl")) then 
	file_ncl = diri + "cdas1.t00z.pgrbhanl.grib2"
end if
output_file = diri+field+"_VertLevel"+sprintf("%2.0fhPa",VertLevel/100)
wks = gsn_open_wks("png",output_file)

itime = 0

ff = addfile(file_ncl,"r")
zgrid = ff->HGT_P0_L100_GLL0({lv_ISBL0|VertLevel},lat_0|:,lon_0|:)
fp = get_speed(ff, "")
fp := fp({lv_ISBL0|VertLevel},lat_0|:,lon_0|:)
printVarSummary(fp)
;fp = get_rain(ff,file_ncl,-6) ; negative dt is important
;fp := fp(itime,:) ; no time dimenstion is important
;fp = where(fp.eq.0,fp@_FillValue,fp)
;fp = sqrt(ff->$field$(2,itime,:))*100.
res := get_field_res(wks, field, fp)
res@cnMaxLevelValF = 290.
;res  = set_res_mp(res, "Joaquin")
res  = set_res_mp(res, "global")
res@tiMainString = file_ncl+"~C~vertical level "+sprintf("%2.0f", VertLevel/100)+"hPa min/avg/max HGT: "+sprintf("%.0fm/",min(zgrid))+sprintf("%.0fm/",avg(zgrid))+sprintf("%.0fm",max(zgrid))
plot = gsn_csm_contour_map(wks,fp,res)
if(isfilevar(ff,"mslp"))then
	slp = ff->mslp(itime,:)/100
	sres := get_res_cn("al","mslp",slp)
	sres = set_res_sf(sres, init, fp, 1)
	sres@cnLineColor = "red"
	plot_ov = gsn_csm_contour(wks,slp,sres)
	overlay(plot,plot_ov)
end if
if(isvar("zgrid"))then
	; To help Michael with NGGPS hindcasts
	printVarSummary(zgrid)
	printMinMax(zgrid,False)
	res@cnFillOn = False
	res@cnLinesOn = True
	res@cnLevelSelectionMode = "AutomaticLevels"
	plot_ov = gsn_csm_contour(wks,zgrid,res)
	overlay(plot,plot_ov)
end if
delete(ff)

draw(plot)
frame(wks)

delete(fp)
print("processing success "+output_file+".png")
end

;=============================================================================================
