;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/work/ahijevyc/ncl/CreateTracks.ncl"
load "/glade/work/ahijevyc/ncl/derived_fields.ncl"
load "/glade/work/ahijevyc/ncl/run_esmf_regrid2.ncl"
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
; setenv NCL_SHARED_OBJ_PATH ~ahijevyc/src/ncl_shared_objects/
;=============================================================================================

begin

wks = gsn_open_wks("png",outfile)

f = addfile(dfile,"r")
print("processing file "+dfile)
iTime = 0

;SET RESOURCES:
res = True

res@mpProjection        = "CylindricalEquidistant"
res@mpDataBaseVersion   = "MediumRes"
res@mpGridAndLimbOn = True
res@mpGridLineDashPattern = 2
res@mpGridSpacingF = 5.
if(.not.isvar("minlat"))then
	print("track_zoom.ncl requires minlat, maxlat, minlon, maxlon to be pre-defined")
	exit
end if
res@mpMinLatF  =  minlat
res@mpMaxLatF  =  maxlat
res@mpMinLonF  =  minlon
res@mpMaxLonF  =  maxlon
lat0=0.5*(minlat+maxlat)
lon0=0.5*(minlon+maxlon)

res@cnInfoLabelOn = False
res@tiMainFontAspectF = 1.4
res@tiMainFont = 21
res@tiMainFontHeightF = 0.02
xtime = str_strip(chartostring(f->xtime))
res@tiMainString    = wnd+" "+fhour+"h fcst Valid: "+xtime


sres = True
sres@cnLineLabelsOn = True
sres@cnLineLabelDensityF = 0.80

if(isfilepresent(systemfunc("dirname "+dfile)+"/init.nc"))then
	file_ncl = systemfunc("dirname "+dfile)+"/init.nc"
else 
	print("track_zoom.ncl expects init.nc in "+dfile+" directory")
	exit
end if
ff = addfile(file_ncl,"r")
res = set_res_sf(res, ff, ff->lonCell, 1) 
sres = set_res_sf(sres, ff, ff->lonCell, 1) 
verticesOnCell = ff->verticesOnCell
cellsOnCell    = ff->cellsOnCell
nEdgesOnCell   = ff->nEdgesOnCell
latVertex      = ff->latVertex
dv             = dimsizes(verticesOnCell)
maxEdges = dv(1)
nv = dimsizes(latVertex)
nc = dimsizes(res@sfXArray)
terrain = ff->zgrid(:,0)

; Hurricane symbol to put in center
tklon = asciiread(tklon_file,-1,"float")
tklat = asciiread(tklat_file,-1,"float")
tkres = True
ivmax = str_index_of_substr(wnd," kt",1)
vmax = stringtoint(str_get_cols(wnd,ivmax-3,ivmax))
tkres@gsMarkerSizeF=0.017
tkres@gsMarkerIndex = create_tropical_symbol(wks,lat0,vmax)
tkres@gsMarkerColor = "Black"

; Cosmetic changes for wind barbs
vres = True
vres@gsnDraw = False
vres@gsnFrame = False
vres@vcRefLengthF    = 0.033
vres@vcGlyphStyle = "WindBarb"
vres@vcPositionMode = "ArrowHead"
vres@vcMinDistanceF = 0.035
vres@vcRefAnnoOn = False
vres@vcWindBarbLineThicknessF = 1.6
vres@vcWindBarbScaleFactorF = 1.94384
vres@gsnLeftString = "" ; Don't overwrite other labels. Wind speed already has these covered.
vres@gsnRightString = ""


;===========================================
;==== Sensible and Latent Heat Flux --===
if (isfilevar(f, "hfx") .and. isfilevar(f, "lh")) then
	gsn_define_colormap(wks,"hotcold_18lev")

	hfx := f->hfx(iTime,:)
	res = get_field_res(wks, "hfx", hfx)
	plot = gsn_csm_contour_map(wks,hfx,res)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
    if(dimsizes(tklon).gt.1)then
    	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
    end if
	draw(plot)
	frame(wks)
	delete(hfx)

	lh := f->lh(iTime,:)
	res = get_field_res(wks, "lh", lh)
	plot = gsn_csm_contour_map(wks,lh,res)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
    if(dimsizes(tklon).gt.1)then
    	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
    end if
	draw(plot)
	frame(wks)
end if

pss = (/"850","500"/)
do ips = 0, dimsizes(pss)-1 
	;Z and VORTICITY:
	presshPa = pss(ips)
	vort_var = "vorticity_"+presshPa+"hPa"

	; interpolate vorticity from vertices to cell
	; create place-holder variable with same dimensions as a cell-based field (height. will use later.)
	height_var = "height_"+presshPa+"hPa"
	height = f->$height_var$(iTime,:)
	sres = get_res_cn("",height_var,height) ; get contour interval
	sres = set_res_sf(sres,ff,height,1) ; smooth?
	fld := f->$vort_var$(iTime,:)

	res = get_field_res(wks, vort_var, fld) ; moved down here after fld is defined
    res@nSmoothPasses = 10
    res = set_res_sf(res, ff, fld, 1)

	plot = gsn_csm_contour_map(wks,fld,res)
    res@cnInfoLabelOn = False ; Don't attach vorticity info label to res forever.
	plot_ov = gsn_csm_contour(wks,height,sres)
	overlay(plot,plot_ov)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
    if(dimsizes(tklon).gt.1)then
    	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
    end if
	draw(plot)
	frame(wks)
	print(presshPa + "hPa Z and Vorticity")

	;Z and RH:
	RH_var = "relhum_"+presshPa+"hPa"
	if (isfilevar(f,RH_var)) then
		fld := f->$RH_var$(iTime,:)
		res = get_field_res(wks, RH_var, fld)
        res = set_res_sf(res, ff, fld, 1)
		fld = mask(fld,height.gt.terrain,True)
		plot = gsn_csm_contour_map(wks,fld,res)
		plot_ov = gsn_csm_contour(wks,height,sres)
		overlay(plot,plot_ov)

		; If ncl/6.2.1 is not loaded, the following plot always fails with Inappropriate ioctl device.
		uvar = "uzonal_"+presshPa+"hPa"
		vvar = "umeridional_"+presshPa+"hPa"
		domain = basin
		meshdir = "/glade/work/mpasrt/rt2015/"
		domain@meshdir = meshdir + "esmf_regrid."+mpas
		u := run_ESMF_regrid(domain,ff,f->$uvar$)
		v := run_ESMF_regrid(domain,ff,f->$vvar$)
		print("done regridding u & v ")
		plot_ov = gsn_csm_vector(wks,u,v,vres)
		overlay(plot,plot_ov)

		sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
        if(dimsizes(tklon).gt.1)then
            tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
        end if
		draw(plot)
		frame(wks)
		print(presshPa + "hPa Z RH and wind barbs")
	end if

end do

;==== dBZ =====
fld := f->refl10cm_max(iTime,:)
res = get_field_res(wks, "refl10cm_max",fld)
res = set_res_sf(res, ff, fld, 1)

plot = gsn_csm_contour_map(wks,fld,res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
if(dimsizes(tklon).gt.1)then
    tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
end if
draw(plot)
frame(wks)
print("dBZ")



; ====== OLR ======
fld := f->olrtoa(iTime,:)
res = get_field_res(wks, "olrtoa",fld)

plot = gsn_csm_contour_map(wks,fld,res)
add_wind_barbs = False
if(add_wind_barbs)then
    ush = f->uzonal_200hPa - f->uzonal_850hPa
    vsh = f->umeridional_200hPa - f->umeridional_850hPa
    copy_VarCoords(f->uzonal_200hPa, ush)
    copy_VarCoords(f->uzonal_200hPa, vsh)
    u := run_ESMF_regrid(domain,ff,ush)
    v := run_ESMF_regrid(domain,ff,vsh)
    print("done regridding u & v shear")
    ; Cosmetic changes for wind barbs
    vres@gsnLeftString = "850-200hPa wind shear"
    vres@gsnRightString = "[kt]"
    plot_ov = gsn_csm_vector(wks,u,v,vres)
    overlay(plot,plot_ov)
    vres@gsnLeftString = "" ; Don't overwrite other labels when using vres in the future. Wind speed already has these covered.
    vres@gsnRightString = ""
end if
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
if(dimsizes(tklon).gt.1)then
    tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
end if
draw(plot)
frame(wks)


; ===== PW =====
fld := f->precipw(iTime,:)
res = get_field_res(wks, "precipw",fld)

plot = gsn_csm_contour_map(wks,fld,res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
if(dimsizes(tklon).gt.1)then
    tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
end if
draw(plot)
frame(wks)


; ===== rain =====
fld := get_rain(f,dfile,-6)
res = get_field_res(wks, "rain6h",fld)
res@cnLevels = res@cnLevels * 2.

plot = gsn_csm_contour_map(wks,fld(iTime,:),res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
if(dimsizes(tklon).gt.1)then
    tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
end if
draw(plot)
frame(wks)
print("rain6h")


if (isfilevar(f,"u10")) then
	;====MSLP and 10-m Wind Speed =====
	fld := get_speed(f,"10m")
	res = get_field_res(wks, "speed_10m", fld)
    ; Special color bar with Saffir-Simpson wind scale
    res@cnLevelSelectionMode = "ExplicitLevels"
    res@cnLevels :=  (/ 34, 45, 55, 64, 75, 83, 96, 113 /)
    res@lbLabelStrings := (/ "34~C~TS", "45", "55", "64~C~Cat 1", "75", "83~C~Cat 2", "96~C~Cat 3", "113~C~Cat 4" /) 
    ; If not set to True, some labels may be skipped due to potential overlap.
    res@lbAutoManage = True

	; get_speed returns knots
	plot = gsn_csm_contour_map(wks,fld(iTime,:),res)
	if (max(fld).gt.0) then 
		u := run_ESMF_regrid(domain,ff,f->u10)
		v := run_ESMF_regrid(domain,ff,f->v10)
		print("done regridding u & v wind")

		; Cosmetic changes for wind barbs
		; use same resource as wind shear
		plot_ov = gsn_csm_vector(wks,u,v,vres)
		overlay(plot,plot_ov)
	end if

	; replace 2D variable (with time dimension) returned from get_speed()
	fld := f->mslp(iTime,:)
	sres = get_res_cn("", "mslp", fld)
	sres = set_res_sf(sres,ff,fld,1) ; smooth?
	sres@cnLineThicknessF = 1.5

	plot_ov = gsn_csm_contour(wks,fld,sres)
	overlay(plot,plot_ov)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
    if(dimsizes(tklon).gt.1)then
        tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
    end if
	draw(plot)
	frame(wks)
	print("MSLP and 10-m wind")
end if



delete(f)
delete(ff)

print("created "+outfile)

end

