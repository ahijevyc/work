;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/p/work/ahijevyc/ncl/CreateTracks.ncl"
load "/glade/p/work/mpasrt/rt2015/ncl/derived_fields.ncl"
load "/glade/p/work/mpasrt/rt2015/ncl/run_esmf_regrid.ncl"
load "/glade/p/work/mpasrt/rt2015/ncl/get_field_res.ncl"
; setenv NCL_SHARED_OBJ_PATH ~ahijevyc/src/ncl_shared_objects/
;=============================================================================================

begin

wks = gsn_open_wks("ncgm",outfile)

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
	print "track_zoom.ncl requires minlat, maxlat, minlon, maxlon to be pre-defined"
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
	file_ncl = "/glade/scratch/ahijevyc/"+mpas+"/2014090100/init.nc"
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
nfilt=4
terrain = ff->zgrid(:,0)

; Hurricane symbol to put in center
tklon = asciiread(tklon_file,-1,"float")
tklat = asciiread(tklat_file,-1,"float")
tkres = True
ivmax = str_index_of_substr(wnd," kt",1)
vmax = stringtoint(str_get_cols(wnd,ivmax-3,ivmax))
tkres@gsMarkerSizeF=0.02
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


;===========================================
;==== Sensible and Latent Heat Flux --===
	if (isfilevar(f, "hfx") .and. isfilevar(f, "lh")) then
	gsn_define_colormap(wks,"hotcold_18lev")

	hfx := f->hfx(iTime,:)
	res = get_field_res(wks, "hfx", hfx)
	plot = gsn_csm_contour_map(wks,hfx,res)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
	draw(plot)
	frame(wks)
	delete(hfx)

	lh := f->lh(iTime,:)
	res = get_field_res(wks, "lh", lh)
	plot = gsn_csm_contour_map(wks,lh,res)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
	draw(plot)
	frame(wks)
	delete(lh)
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
	mpas_filter_cells(nEdgesOnCell, cellsOnCell, maxEdges, nc, todouble(height), nfilt)
	fieldin_tmp = f->$vort_var$(iTime,:)
	fld := tofloat(height)
	mpas_vort_cell1(nEdgesOnCell, verticesOnCell, maxEdges, nc, nv, todouble(fieldin_tmp), fld )

	res = get_field_res(wks, vort_var, fld) ; moved down here after fld is defined

	fld = mask(fld,height.gt.terrain,True)
	plot = gsn_csm_contour_map(wks,fld,res)
	delete(fld)
	plot_ov = gsn_csm_contour(wks,height,sres)
	overlay(plot,plot_ov)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
	draw(plot)
	frame(wks)
	print(presshPa + "hPa Z and Vorticity")


	;Z and RH:
	RH_var = "relhum_"+presshPa+"hPa"
	if (isfilevar(f,RH_var)) then
		fld := f->$RH_var$(iTime,:)
		res = get_field_res(wks, RH_var, fld)
		fld = mask(fld,height.gt.terrain,True)
		plot = gsn_csm_contour_map(wks,fld,res)
		delete(fld)
		plot_ov = gsn_csm_contour(wks,height,sres)
		overlay(plot,plot_ov)

		; If ncl/6.2.1 is not loaded, the following plot always fails with Inappropriate ioctl device.
		uvar = "uzonal_"+presshPa+"hPa"
		vvar = "umeridional_"+presshPa+"hPa"
		domain = basin
		mesh = mpas
		if(mpas.eq."mpas15_3")then
			mesh = "pecan"
		end if
		if(mpas.eq."mpas50_3")then
			mesh = "spring_exp"
		end if
		meshdir = "/glade/p/work/mpasrt/rt2015/"
		; If 2014 date use 2014 mpas mesh.
		; str_match_regex not available in ncl 6.2
		if(.not.ismissing(str_match(dfile,"2014")))then
			meshdir = "/glade/p/work/mpasrt/2014/"
		end if
		domain@meshdir = meshdir + "esmf_regrid."+mesh
		u = run_ESMF_regrid(domain,ff,f->$uvar$)
		v = run_ESMF_regrid(domain,ff,f->$vvar$)
		print("done regridding u & v ")
		plot_ov = gsn_csm_vector(wks,u,v,vres)
		delete([/u,v/])
		overlay(plot,plot_ov)

		sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
		tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
		draw(plot)
		frame(wks)
		print(presshPa + "hPa Z RH and wind barbs")
	end if

end do

;==== dBZ =====
fld := f->refl10cm_max(iTime,:)
res = get_field_res(wks, "refl10cm_max",fld)
delete(res@nSmoothPasses)
delete(sres@nSmoothPasses)

plot = gsn_csm_contour_map(wks,fld,res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
draw(plot)
frame(wks)
print("dBZ")



; ====== OLR ======
fld := f->olrtoa(iTime,:)
res = get_field_res(wks, "olrtoa",fld)

plot = gsn_csm_contour_map(wks,fld,res)

; If ncl/6.2.1 is not loaded, the following plot always fails with Inappropriate ioctl device.
ush = f->uzonal_200hPa - f->uzonal_850hPa
vsh = f->umeridional_200hPa - f->umeridional_850hPa
copy_VarCoords(f->uzonal_200hPa, ush)
copy_VarCoords(f->uzonal_200hPa, vsh)
u = run_ESMF_regrid(domain,ff,ush)
v = run_ESMF_regrid(domain,ff,vsh)
print("done regridding u & v shear")
; Cosmetic changes for wind barbs
vres@gsnLeftString = "850-200hPa wind shear"
vres@gsnRightString = "[kt]"
plot_ov = gsn_csm_vector(wks,u,v,vres)
delete([/u,v/])
overlay(plot,plot_ov)

sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
draw(plot)
frame(wks)


; ===== PW =====
fld := f->precipw(iTime,:)
res = get_field_res(wks, "precipw",fld)

plot = gsn_csm_contour_map(wks,fld,res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
draw(plot)
frame(wks)


; ===== rain =====
fld := get_rain(f,dfile,-6)
res = get_field_res(wks, "rain6h",fld)

plot = gsn_csm_contour_map(wks,fld(iTime,:),res)
sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
draw(plot)
frame(wks)
print("rain6h")


if (isfilevar(f,"u10")) then
	;====MSLP and 10-m Wind Speed =====
	fld := get_speed(f,"10m")
	res = get_field_res(wks, "speed_10m", fld)
	res@cnMaxLevelValF = 75.
	; get_speed returns knots
	plot = gsn_csm_contour_map(wks,fld(iTime,:),res)
	if (max(fld).gt.0) then 
	; I have to load an old (non-default) version of NCL to make it work without a 
	; seg fault.
		u = run_ESMF_regrid(domain,ff,f->u10)
		v = run_ESMF_regrid(domain,ff,f->v10)
		print("done regridding u & v wind")

		; Cosmetic changes for wind barbs
		; use same resource as wind shear
		delete(vres@gsnLeftString)
		delete(vres@gsnRightString)
		plot_ov = gsn_csm_vector(wks,u,v,vres)
		delete([/u,v/])
		overlay(plot,plot_ov)
	end if

	delete(fld) ; delete 2D variable (with time dimension) returned from get_speed()
	fld = f->mslp(iTime,:)
	sres = get_res_cn("", "mslp", fld)
	delete(sres@nSmoothPasses)
	sres@cnLineThicknessF = 1.5
	;mpas_filter_cells::mpas_filter_cells(nEdgesOnCell, cellsOnCell, maxEdges, nc, fld, nfilt )

	plot_ov = gsn_csm_contour(wks,fld,sres)
	overlay(plot,plot_ov)
	sym = gsn_add_polymarker(wks,plot,lon0,lat0,tkres)
	tk = gsn_add_polyline(wks,plot,tklon,tklat,tkres)
	draw(plot)
	frame(wks)
	print("MSLP and 10-m wind")
end if



delete(f)
delete(ff)

print("created "+outfile)

end

