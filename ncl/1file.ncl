;=============================================================================================
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;=============================================================================================

begin
if(.not.isvar("date")) then
 date = "2016082700"
end if

if(.not.isvar("fieldname")) then 
 fieldname = "height_200hPa"
end if
if(.not.isvar("mesh")) then 
 mesh = "wp"
end if
if(.not.isvar("VertLevel"))then
	VertLevel = 0
end if
if(.not.isvar("fday"))then
	fday=0
end if
if(.not.isvar("file_ncl")) then 
	file_ncl = "/glade/scratch/ahijevyc/"+mesh+"/"+date+"/diag.2016-08-27_00.00.00.nc"
end if
diri = systemfunc("dirname "+file_ncl)+"/"
output_file = "./"+systemfunc("basename "+file_ncl+" nc")+fieldname+"."+sprintf("%02.0fday",fday)+".VertLevel"+sprintf("%02.0f",VertLevel)
print("output file: "+output_file)
wks = gsn_open_wks("png",output_file)

r2d = 180.0d/(atan(1)*4.0d) ; conversion from radians to degrees. 
; don't assume 0901 exists. Look for all init.nc files under date directories and use first one.
init_files = systemfunc("ls "+diri+"../20??[01]?????/init.nc "+diri+"init.nc")
; print(init_files)
init = addfile(init_files(0),"r")
verticesOnCell = init->verticesOnCell
xlat = tofloat(init->latCell * r2d)
zgrid = init->zgrid(:,VertLevel)
zgrid@long_name = "zgrid (height)"
zgrid@units = "m"
dv = dimsizes(verticesOnCell)
nCells = dv(0)
maxEdges = dv(1)
iTime = 0

print("opening "+file_ncl)
f = addfile(file_ncl,"r")
fp = f->$fieldname$
fp := get_speed(f, "200hPa")
if(isdim(fp,"nVertLevelsP1").or.isdim(fp,"nVertLevels"))then
	fp := fp(:,:,VertLevel)
end if
printVarSummary(fp)
;fp = get_rain(f,file_ncl,-6) ; negative dt is important
if(isdim(fp,"lead_time"))then
	print("grabbing lead_time="+tostring(fday))
	fp := fp(fday,iTime,:) ; Removing time dimension is important
else
	fp := fp(iTime,:) ; no time dimenstion is important
end if
;fp = where(fp.eq.0,fp@_FillValue,fp)
;fp = sqrt(f->$fieldname$(2,iTime,:))*100.
domain = "global"
fp := f->temperature_200hPa(iTime,:)
res := get_field_res(wks, "temperature_200hPa", fp)
res  = set_res_mp(res, domain)
res  = set_res_sf(res, init, fp, 1)
res@tiMainString = str_get_cols(file_ncl, 0, -1)
;res@tiMainString = str_get_cols(file_ncl+"~C~vertical level "+sprintf("%2.0f", VertLevel)+" min/avg/max zgrd: "+sprintf("%.0fm/",min(zgrid))+sprintf("%.0fm/",avg(zgrid))+sprintf("%.0fm",max(zgrid)), 31, -1)
;print(res)
printMinMax(fp,False)
;plot = gsn_csm_contour_map(wks,fp,res)
if(False.and.isfilevar(f,"mslp"))then
	slp = f->mslp(iTime,:)/100
	sres := get_res_cn("al","mslp",slp)
	sres = set_res_sf(sres, init, fp, 1)
	sres@cnLineColor = "red"
	plot_ov = gsn_csm_contour(wks,slp,sres)
	overlay(plot,plot_ov)
end if
if(True.and.fieldname.eq."height_200hPa")then
	hgt = f->height_200hPa(iTime,:)
	sres := get_res_cn(domain,fieldname,hgt)
	sres@nSmoothPasses = 0
	sres = set_res_sf(sres, init, hgt, 1)
	; Deal with geometric height
	fix_geometric = False
	if(fix_geometric)then
		geometric_height = f->height_200hPa
		hgt := geometric_height
		compute_geopotential_height(1, nCells, geometric_height, xlat, hgt)
		delete(geometric_height)
		hgt := hgt(iTime,:)
		hgt@long_name = "200hPa Geopotential Height"
		hgt@units = "m"
	else
		hgt@long_name = "200hPa Geometric Height"
	end if
	sres@cnLineLabelFontHeightF = 0.008
	sres@cnLineThicknessF = 2.
	sres@cnLevelSpacingF=40.
	res := get_field_res(wks, fieldname, hgt)
	res@cnLevelSelectionMode = "ManualLevels"
	res@cnMinLevelValF = 11500.
	res@cnLevelSpacingF = 60.
	res  = set_res_mp(res, domain)
	res  = set_res_sf(res, init, fp, 1)
	plot = gsn_csm_contour_map(wks,hgt,res)
	plot_ov = gsn_csm_contour(wks,hgt,sres)
	overlay(plot,plot_ov)
end if
if(fieldname.eq."APCP_P8_L1_GLL0_acc6h".and.isfilevar(init,"zgrid"))then
	; To help Michael with NGGPS hindcasts
	printVarSummary(zgrid)
	printMinMax(zgrid,False)
	res = set_res_sf(res, init, zgrid, 1)
	res@cnFillOn = False
	res@cnLinesOn = True
	plot_ov = gsn_csm_contour(wks,zgrid,res)
	overlay(plot,plot_ov)
end if
delete(f)

draw(plot)
frame(wks)

delete(fp)
print("processing success "+output_file+".png")
end

;=============================================================================================
