load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"


; Function called by run_remove_storm.ncl
; I don't think it works for MPAS mesh.

; Optional resource res@ofile can be set to file name string to which diagnostic 
; fields will be written e.g. vorticity, divergence, steering flow, and U/V without storm. 

undef("remove_storm")
function remove_storm(Uin:numeric, Vin:numeric, center_lat:numeric, center_lon:numeric, res)
begin
	U = Uin
	V = Vin
	if(dimsizes(dimsizes(U)).ne.2)then
		print("remove_storm() expects 2-d U wind")
		exit
	end if

	; If-clause bypasses work for special case of zero radius.
	if(res@rx.eq.0)then
		tmp = (/U,V/)
		tmp@U = default_fillvalue(typeof(U))
		tmp@V = default_fillvalue(typeof(V))
		return(tmp)
	end if

	vardims = getvardims(U)
	fliplat = False
	; for lat/lon grids
	if(any(vardims.eq."lon_0").and.any(vardims.eq."lat_0"))then
		; make sure lat is ascending for uv2dvF
		if(U&lat_0(0).gt.U&lat_0(1))then
			print("To use uv2dvF, latitude input must ascend. Reversing lat_0 dimension of U and V")
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
		;tmp := new(array_append_record(2,dimsizes(U),0),float) ; tried moving below
		if(.not.isatt(U,"lat2d"))then
			print("remove_storm.ncl: U must have lat2d attribute")
		end if
		lat2d = U@lat2d
		lon2d = U@lon2d
		delete(U@lat2d)
		delete(U@lon2d)
	end if


	global =  max(lat2d)-min(lat2d) .ge. 85

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
	nvrt=where(ismissing(radius).or.radius.gt.res@rx,0,vrt)
	copy_VarCoords(vrt,nvrt)
	copy_VarCoords(div,ndiv)
	; My grid is Fixed, so use dv2uvF. 
	; dv2uvF_Wrap preserves metadata.
	; Convert divergence and vorticity of storm to U and V components
	uv = dv2uvF_Wrap(ndiv)
	uc = uv(0,:,:)
	vc = uv(1,:,:)
	uv := vr2uvF_Wrap(nvrt)
	up = uv(0,:,:)
	vp = uv(1,:,:)
	; Subtract divergence and vorticity of storm from original wind components.
	UR=U-uc-up
	copy_VarMeta(U,UR)
	VR=V-vc-vp
	copy_VarMeta(V,VR)
	tmp := new(array_append_record(2,dimsizes(U),0),float)
	tmp!0 = "uv"
	tmp(0,:,:) = UR
	tmp(1,:,:) = VR
	Uavg := avg(mask(UR,radius.le.res@rx,True))
	Vavg := avg(mask(VR,radius.le.res@rx,True))
	;print(sprintf("%.1f",res@rx)+" "+res@units+" radius steering flow:" +tostring(Uavg)+" "+tostring(Vavg))
	tmp@U = Uavg
	tmp@V = Vavg
	if(isatt(res,"ofile"))then
		if(fileexists(res@ofile))then
			print(systemfunc("rm -fv "+res@ofile))
		end if
		ofile = addfile(res@ofile,"c")
		ofile->U = U
		ofile->V = V
		ofile->ndiv = ndiv
		ofile->nvrt = nvrt
		ofile->div = div
		ofile->vrt = vrt
		ofile->UR = UR
		ofile->VR = VR
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
		tmp := rgrid2rcm_Wrap(lat, lon, tmp, lat2d, lon2d, 1)
	end if
	if(fliplat)then
		print("Flipping lat_0 dimension of tmp")
		tmp = tmp(uv|:,lat_0|::-1,lon_0|:)
	end if
	return(tmp)
end
