; Function called by run_remove_storm.ncl
; Only works on 2-D lat/lon grid, not 1-D MPAS mesh.

; Removes vorticity and divergence (rotational and irrotational wind) around
; specified lat/lon (storm center).  Radius is controlled by resource 
; attribute res@rx.

;-----------------------------------------------------------------------------
; INPUT
;-----------------------------------------------------------------------------
; Uin - zonal wind (typically deep layer average)
; Vin - meridional wind (typically deep layer average)
; center_lat - latitude (deg) of storm center
; center_lon - longitude (deg) of storm center
; res - resources
; 	res@rx - float, radius of storm removal (deg or km)
;	res@units - string, optional "km" or "deg" ("deg" is default)
; 	res@ofile - string, optional output netCDF file name

;-----------------------------------------------------------------------------
; OUTPUT
;-----------------------------------------------------------------------------
; UV - combination of UR and VR wind output (winds with storm removed)
; 	UV(0,:,:) = UR
;	UV(1,:,:) = VR
;	UV@U - average zonal steering flow over storm
;	UV@V - average meridional steering flow over storm
; res@ofile - optional output netCDF file 
;	Resource attribute res@ofile may be set to output file name string
;	to which intermediate diagnostic fields will be written e.g. vorticity, 
;	divergence, steering flow, and U/V without storm. 

;-----------------------------------------------------------------------------
; METHODOLOGY
;-----------------------------------------------------------------------------
; 1) If not global, interpolate to global grid.
; 2) Calculate vorticity and divergence.
; 3) Set both to zero outside storm.
; 4) Convert divergence and vorticity of storm to U and V components
; 5) Subtract divergence and vorticity of storm from original wind components.
; 6) Calculate vorticity and diverence without storm (optional diagnostic output).
; 7) Average U and V without storm around storm (steering flow)
; 8) If not global, interpolate back to regional grid.


undef("remove_storm")
function remove_storm(Uin:numeric, Vin:numeric, center_lat:numeric, center_lon:numeric, res)
local U, V
begin
	U = Uin
	V = Vin
	r2d = 180.0d/(atan(1)*4.0d) ; radian to degree
	if(dimsizes(dimsizes(U)).ne.2)then
		print("remove_storm() expects 2-d U wind")
		exit
	end if

	; If-clause bypasses work for special case of zero radius.
	if(res@rx.eq.0)then
		UV = (/U,V/)
		UV@U = default_fillvalue(typeof(U))
		UV@V = default_fillvalue(typeof(V))
		return(UV)
	end if

	vardims = getvardims(U)
	fliplat = False
	; for lat/lon grids
	if(any(vardims.eq."lon_0").and.any(vardims.eq."lat_0"))then
		; make sure lat is ascending for uv2dvF
		if(U&lat_0(0).gt.U&lat_0(1))then
			;print("To use uv2dvF, latitude input must ascend. Reversing lat_0 dimension of U and V")
			U = U(lat_0|::-1,lon_0|:)
			V = V(lat_0|::-1,lon_0|:)
			fliplat = True
		end if
		lat2d = conform(U,U&lat_0,0)
		lon2d = conform(U,U&lon_0,1)
	end if

	; for some WRF. lat2d and lon2d can't be derived easily from WRF lambert conformal grid; 
	; must be taken from XLAT or XLONG variables. Do in preceding (calling) script.
	if(any(vardims.eq."south_north"))then
		;UV := new(array_append_record(2,dimsizes(U),0),float) ; tried moving below
		if(.not.isatt(U,"lat2d"))then
			print("remove_storm.ncl: U must have lat2d attribute")
		end if
		lat2d = U@lat2d
		lon2d = U@lon2d
		delete(U@lat2d)
		delete(U@lon2d)
	end if

	; Is this a global grid? If not, it will be interpolated to global.
	global =  max(lat2d)-min(lat2d) .ge. 85

	; What radius to remove?
	iu = 2
	if(isatt(res,"units"))then
		if(res@units.eq."degrees")then
			iu = 2
		end if
		if(res@units.eq."km")then
			iu = 4
		end if
	end if
	radius=gc_latlon(center_lat,center_lon,lat2d,lon2d,2,iu) ; for last arg, 2=degrees.
	copy_VarCoords(U,radius)


	; Get divergence and vorticity
	if(.not.global)then
		dx = 0.5
		print("Interpolating to "+sprintf("%3.1f",dx)+"deg global lat/lon grid.")
		; Tom Galarneau interpolates to global grid to use Fixed grid functions for div/vrt and their inverse.
		lat = fspan(-90, 90, toint(180/dx)+1)
		lon = fspan(-180, 180, toint(360/dx)+1)
		printMinMax(U,False)
		U := rcm2rgrid_Wrap(lat2d,lon2d,U,lat,lon,1)
		printMinMax(U,False)
		U = where(ismissing(U),0,U)
		V := rcm2rgrid_Wrap(lat2d,lon2d,V,lat,lon,1)
		V = where(ismissing(V),0,V)
		radius := rcm2rgrid_Wrap(lat2d,lon2d,radius,lat,lon,1)
	end if
	div = uv2dvF_Wrap(U,V)
	vrt = uv2vrF_Wrap(U,V)
	; Set divergence and vorticity to zero outside radius.
	ndiv=where(ismissing(radius).or.radius.gt.res@rx,0,div)
	copy_VarMeta(div,ndiv)
	ndiv@long_name = ndiv@long_name + " of storm"
	nvrt=where(ismissing(radius).or.radius.gt.res@rx,0,vrt)
	copy_VarMeta(vrt,nvrt)
	nvrt@long_name = nvrt@long_name + " of storm"
	; My grid is Fixed, so use dv2uvF. 
	; dv2uvF_Wrap preserves metadata.
	; Convert divergence and vorticity of storm to U and V components
	uv = dv2uvF_Wrap(ndiv)
	uc = uv(0,:,:)
	vc = uv(1,:,:)
	uc@long_name = "zonal wind component of " + ndiv@long_name
	vc@long_name = "meridional wind component of " + ndiv@long_name
	uv := vr2uvF_Wrap(nvrt)
	up = uv(0,:,:)
	vp = uv(1,:,:)
	up@long_name = "zonal wind component of " + nvrt@long_name
	vp@long_name = "meridional wind component of " + nvrt@long_name
	; Subtract divergence and vorticity of storm from original wind components.
	UR=U-uc-up
	copy_VarMeta(U,UR)
    ; Might get warning about no long_name attribute if using ncl version 6.4.0.
    ; That is because it doesn't propogate attributes from the wgt_vertical_n() function.
	UR@long_name = UR@long_name + " without storm"
	VR=V-vc-vp
	copy_VarMeta(V,VR)
	VR@long_name = VR@long_name + " without storm"
	; Calculate vorticity and diverence without storm.
	divR = uv2dvF_Wrap(UR,VR)
	divR@long_name = divR@long_name + " without storm"
	vrtR = uv2vrF_Wrap(UR,VR)
	vrtR@long_name = vrtR@long_name + " without storm"
	UV := new(array_append_record(2,dimsizes(U),0),float)
	UV!0 = "uv"
	UV(0,:,:) = UR
	UV(1,:,:) = VR
	; switched from <= to < Sep 30, 2016
	; switched from avg() to wgt_areaave_Wrap Dec 12, 2016
	Uavg := wgt_areaave_Wrap(mask(UR,radius.lt.res@rx,True),cos(UR&$UR!0$/r2d),1.0,0)
	copy_VarAtts(UR, Uavg)
	Vavg := wgt_areaave_Wrap(mask(VR,radius.lt.res@rx,True),cos(VR&$VR!0$/r2d),1.0,0)
	copy_VarAtts(VR, Vavg)
	;print(sprintf("%.1f",res@rx)+" "+res@units+" radius steering flow:" +tostring(Uavg)+" "+tostring(Vavg))
	UV@U = Uavg
	UV@V = Vavg
	if(isatt(res,"ofile").and.res@ofile.ne."")then
		if(fileexists(res@ofile))then
			print(systemfunc("rm -fv "+res@ofile))
		end if
		ofile = addfile(res@ofile,"c")
		ofile->U = U
		ofile->V = V
		ofile->div = div
		ofile->vrt = vrt
		ofile->ndiv = ndiv
		ofile->nvrt = nvrt
		ofile->uc = uc
		ofile->vc = vc
		ofile->up = up
		ofile->vp = vp
		ofile->UR = UR
		ofile->VR = VR
		ofile->divR = divR
		ofile->vrtR = vrtR
		ofile->Uavg = Uavg
		ofile->Vavg = Vavg
		rx := res@rx
		rx@units = res@units
		rx@long_name = "radius of storm removal"
		rx@center_lon = center_lon
		rx@center_lat = center_lat
		ofile->rx = rx
		print("created remove_storm.ncl diagnostic file: "+res@ofile)
	end if
	if(.not.global)then
		UV := rgrid2rcm_Wrap(lat, lon, UV, lat2d, lon2d, 1)
	end if
	if(fliplat)then
		;print("remove_storm: Flipping lat_0 dimension of UV")
		UV = UV(uv|:,lat_0|::-1,lon_0|:)
	end if
	return(UV)
end

