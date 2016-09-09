;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;=============================================================================================

begin
if(.not.isvar("date")) then
 date = "2015093000"
end if

if(.not.isvar("field")) then 
 field = "temperature_200hPa"
end if
if(.not.isvar("mesh")) then 
 mesh = "al"
end if
if(.not.isvar("VertLevel"))then
	VertLevel = 0
end if
if(.not.isvar("fday"))then
	fday=1
end if
if(.not.isvar("file_ncl")) then 
	file_ncl = "/glade/p/nmmm0024/"+mesh+"/"+date+"/ec/diag.2015-10-01_00.00.00.nc"
end if
diri = systemfunc("dirname "+file_ncl)+"/"
output_file = "./"+systemfunc("basename "+file_ncl+" nc")+field+"."+sprintf("%02.0fday",fday)+".VertLevel"+sprintf("%02.0f",VertLevel)
print("opening "+output_file)
wks = gsn_open_wks("png",output_file)

;SET RESOURCES:
res = True
res@gsnDraw   = False
res@gsnFrame  = False
;res@gsnLeftString = "850hPa vertical velocity"
;res@gsnRightString = "[m/s]"
res@cnFillOn = True
res@cnLinesOn = False
res@cnFillMode = "RasterFill"
res@cnLevelSelectionMode = "ExplicitLevels"
;res@cnLevels = 100 * (/-.5,-.2,-.1,-.05,-0.02,-0.01,0,0.01,0.02,0.05,0.1,0.2,0.5/)
res@cnLevels = (/12000,12060,12120,12180,12240,12300,12360,12420,12480,12540,12600./)
res@mpLimitMode = "Corners"
res@mpLeftCornerLatF = 17
res@mpLeftCornerLonF = -80
res@mpRightCornerLatF = 31
res@mpRightCornerLonF = -66

r2d = 180.0d/(atan(1)*4.0d) ; conversion from radians to degrees. 
; don't assume 0901 exists. Look for all init.nc files under date directories and use first one.
init_files = systemfunc("ls "+diri+"../20??[01]?????/init.nc "+diri+"init.nc")
; print(init_files)
init = addfile(init_files(0),"r")
nEdgesOnCell = init->nEdgesOnCell
cellsOnCell = init->cellsOnCell
verticesOnCell = init->verticesOnCell
zgrid = init->zgrid(:,VertLevel)
zgrid@long_name = "zgrid (height)"
zgrid@units = "m"
dv = dimsizes(verticesOnCell)
nCells = dv(0)
maxEdges = dv(1)
itime = 0

ff = addfile(file_ncl,"r")
fp = ff->$field$
;fp = get_speed(ff, "200hPa")
if(isdim(fp,"nVertLevelsP1").or.isdim(fp,"nVertLevels"))then
	fp := fp(:,:,VertLevel)
end if
printVarSummary(fp)
;fp = get_rain(ff,file_ncl,-6) ; negative dt is important
if(isdim(fp,"lead_time"))then
	print("grabbing lead_time="+tostring(fday))
	fp := fp(fday,itime,:) ; Removing time dimension is important
else
	fp := fp(itime,:) ; no time dimenstion is important
end if
;fp = where(fp.eq.0,fp@_FillValue,fp)
;fp = sqrt(ff->$field$(2,itime,:))*100.
res := get_field_res(wks, field, fp)
;res@cnLevelSelectionMode="ManualLevels"
;res@cnMinLevelValF = 0.
;res@cnMaxLevelValF = 150.
;res@cnLevelSpacingF = 10.
res  = set_res_mp(res, "Joaquin")
res  = set_res_mp(res, "global")
res  = set_res_sf(res, init, fp, 1)
res@tiMainString = str_get_cols(file_ncl, 0, -1)
;res@tiMainString = str_get_cols(file_ncl+"~C~vertical level "+sprintf("%2.0f", VertLevel)+" min/avg/max zgrd: "+sprintf("%.0fm/",min(zgrid))+sprintf("%.0fm/",avg(zgrid))+sprintf("%.0fm",max(zgrid)), 31, -1)
;print(res)
printMinMax(fp,False)
plot = gsn_csm_contour_map(wks,fp,res)
if(False.and.isfilevar(ff,"mslp"))then
	slp = ff->mslp(itime,:)/100
	sres := get_res_cn("al","mslp",slp)
	sres = set_res_sf(sres, init, fp, 1)
	sres@cnLineColor = "red"
	plot_ov = gsn_csm_contour(wks,slp,sres)
	overlay(plot,plot_ov)
end if
if(False.and.isfilevar(ff,"height_200hPa"))then
	hgt = ff->height_200hPa(itime,:)
	sres := get_res_cn("al","height_200hPa",hgt)
	sres = set_res_sf(sres, init, fp, 1)
	sres@cnLineColor = "red"
	sres@cnLevelSpacingF=10.
	plot_ov = gsn_csm_contour(wks,hgt,sres)
	overlay(plot,plot_ov)
end if
if(field.eq."APCP_P8_L1_GLL0_acc6h".and.isfilevar(init,"zgrid"))then
	; To help Michael with NGGPS hindcasts
	printVarSummary(zgrid)
	printMinMax(zgrid,False)
	res = set_res_sf(res, init, zgrid, 1)
	res@cnFillOn = False
	res@cnLinesOn = True
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
