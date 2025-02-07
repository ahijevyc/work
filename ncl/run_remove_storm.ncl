begin

	; Same function as "/glade/work/ahijevyc/ncl/remove_storm.ncl"
	; but does multiple radii without recalculating the dist array each time
	; and allows a subset of pressure levels to be processed.
	
	; run by ~ahijevyc/bin/run_remove_storm.csh

	stid=getenv("stid")
	init=getenv("init")
	infile=getenv("infile")
	if(.not.isvar("fhr"))then
		fhr = 24
	end if
	if(ismissing(stid))then
		stid = "al11"
	end if
	if(ismissing(init))then
		init = "2015093000"
	end if
	if(.not.isvar("lat0"))
		lat0 = 25.2
	end if
	if(.not.isvar("lon0"))then
		lon0 = 360-73.2
	end if
	yyyymmdd = str_get_cols(init,0,7)
	hh = str_get_cols(init,8,9)
	if(ismissing(infile))then
		infile="/glade/scratch/ahijevyc/GFS/"+init+"/gfdl_tracker/gfs_4_"+yyyymmdd+"_"+hh+"00_"+sprintf("%03.0f",fhr)+".grb2"
	end if
	print(lat0)
	print(lon0)
	; Array of radii in deg. rx=0 results in no change.
	rxs = (/ 0.,4 /)
	rxs@units = "degrees"

	f=addfile(infile,"r")
	outfile=  systemfunc("dirname "+infile)+"/"+yyyymmdd+"_"+hh+"00_"+sprintf("%03.0f",fhr)+".nc"
	system("rm -v "+outfile)
	out=addfile(outfile,"c")
	; Just process these pressure levels.
	ip = (/ 20000, 50000, 70000, 85000, 92500 /)
	varnames = getfilevarnames(f)
	print(varnames)
	Ustr = str_match_ic_regex(varnames, "U.*_(L100_GLL0|221_ISBL)")
	Vstr = str_match_ic_regex(varnames, "V.*_(L100_GLL0|221_ISBL)")
	print(Ustr)
	dimnames = getfiledimnames(f)
	print(dimnames)
    lat_dimname = "lat_0"
    lon_dimname = "lon_0"
	if(any(getfilevardims(f,Ustr).eq."forecast_time0"))then
		U=f->$Ustr$({forecast_time0|fhr},{lv_ISBL0|ip},$lat_dimname$|::-1,$lon_dimname$|:)
		V=f->$Vstr$({forecast_time0|fhr},{lv_ISBL0|ip},$lat_dimname$|::-1,$lon_dimname$|:)
	else
		U=f->$Ustr$({lv_ISBL0|ip},$lat_dimname$|::-1,$lon_dimname$|:)
		V=f->$Vstr$({lv_ISBL0|ip},$lat_dimname$|::-1,$lon_dimname$|:)
	end if
	p = f->lv_ISBL0({lv_ISBL0|ip})
	print(p)
	lat = f->$lat_dimname$(::-1)
	lon = f->$lon_dimname$
	np = dimsizes(p)
	nlat=dimsizes(lat)
	nlon=dimsizes(lon)
	lat2d = conform(U,lat,1)
	lon2d = conform(U,lon,2)
	if(rxs@units.eq."degrees")then
		iu := 2
	end if
	if(rxs@units.eq."kilometers")then
		iu := 4
	end if
	radius=gc_latlon(lat0,lon0,lat2d,lon2d,2,iu) ; 2nd-to-last arg=npts; for last arg, 2=degrees.
	copy_VarCoords(U,radius)
	; make sure lat is ascending for uv2dvF
	if(lat(0).gt.lat(1))then
		print("latitude input must ascend")
		exit
	end if
	div = uv2dvF_Wrap(U,V)
	vrt = uv2vrF_Wrap(U,V)
	UR = new((/dimsizes(rxs),np,nlat,nlon/),"float")
	VR = new((/dimsizes(rxs),np,nlat,nlon/),"float")
	; Loop through radii array.
	do it=0,dimsizes(rxs)-1
		rx=rxs(it)
	        ndiv=where(radius.gt.rx,0,div)
		nvrt=where(radius.gt.rx,0,vrt)
	  	copy_VarCoords(vrt,nvrt)
	        copy_VarCoords(div,ndiv)
		; My grid is Fixed, so use dv2uvF. 
		; dv2uvF_Wrap preserves metadata.
	      	uv = dv2uvF_Wrap(ndiv)
		uc = uv(0,:,:,:)
		vc = uv(1,:,:,:)
	      	uv = vr2uvF_Wrap(nvrt)
		up = uv(0,:,:,:)
		vp = uv(1,:,:,:)
		UR(it,:,:,:)=U-uc-up
		VR(it,:,:,:)=V-vc-vp
		print(rx)
	end do
	UR!0 = "radius"
	UR!1 = "lv_ISBL0"
	UR!2 = lat_dimname
	UR!3 = lon_dimname
	UR&radius = rxs
	UR&lv_ISBL0 = p
	UR&$lat_dimname$ = lat
	UR&$lon_dimname$ = lon
	copy_VarAtts(U,UR)
	UR@long_name = U@long_name + " with "+stid+" storm removed"
	copy_VarMeta(UR,VR)
	VR@long_name = V@long_name + " with "+stid+" storm removed"
	out->UR=UR
	out->VR=VR
	U_steering = new((/dimsizes(rxs), np/),"float")	
	V_steering = new((/dimsizes(rxs), np/),"float")	
	copy_VarMeta(UR,U_steering)
	copy_VarMeta(VR,V_steering)
	U_steering@long_name = "U-component of steering flow"
	V_steering@long_name = "V-component of steering flow"
	if(True)then
		do it=0,dimsizes(rxs)-1
			rx=rxs(it)
			nu=mask(UR(it,:,:,:),radius.gt.rx,False)
			nv=mask(VR(it,:,:,:),radius.gt.rx,False)
			uavg = dim_avg_n_Wrap(nu,(/1,2/))
			vavg = dim_avg_n_Wrap(nv,(/1,2/))
			print(uavg)
			U_steering(it,:) = (/ uavg /)
			V_steering(it,:) = (/ vavg /)
		end do
		out->U_steering = U_steering
		out->V_steering = V_steering
	end if
end
