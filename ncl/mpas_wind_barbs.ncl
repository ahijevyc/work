;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
;==========================================================================

; written by David Ahijevych
; MSLP contour and windbarbs

begin

	field = "speed_10m"
	suffix = "10m"; could be "700hPa"
	init_date = "2015100800"
	fname = "diag.2015-10-10_18.00.00.nc"
	; Fine mesh domain
	domain = "al"; could be "wp" or "ep"
	; Directory with esmf regrid files for this particular MPAS mesh 
	meshdir = "/glade/p/work/mpasrt/rt2015/esmf_regrid.hur15al/"
	;meshdir = "/glade/p/work/mpasrt/rt2015/esmf_regrid.hur15/"
	;meshdir = "/glade/p/work/mpasrt/rt2015/esmf_regrid.hur15ep/"

	diri = "/glade/scratch/mpasrt/"+domain+"/"+init_date+"/"
	filei = diri+"init.nc"
	if (.not.isfilepresent(filei))then
		print(filei+" not present")
		exit
	end if
	; Open initialization file and read lat/lon/cell information.
	ff = addfile(filei,"r")
	cellsOnCell    = ff->cellsOnCell
	nEdgesOnCell   = ff->nEdgesOnCell
	nCells         = dimsizes(nEdgesOnCell)
	print("done reading cell and vertex info")

	f = addfile(diri+fname,"r")
	iTime = 0
	ofile = field+"."+domain+".png"
	print("output file: "+ofile)
	wks_type = "png"
	wks = gsn_open_wks(wks_type,ofile)

	;SET RESOURCES:
	res = True
	res@mpProjection        = "CylindricalEquidistant"
	res@mpDataBaseVersion   = "MediumRes" 
	res@mpLimitMode = "LatLon"
	res@mpMinLatF=   5.
	res@mpMaxLatF=  45.
	res@mpMinLonF=-100.
	res@mpMaxLonF= -20.
	; set sfXArray and sfYarray (1-D lats and lons needed for plotting a mesh)
	RAD2DEG = 180.0d/(atan(1)*4.0d)
	res@sfXArray = ff->lonCell * RAD2DEG
	res@sfYArray = ff->latCell * RAD2DEG
  
	res@gsnFrame  = False
	res@cnFillOn  = False
	res@cnLevelSelectionMode = "ManualLevels"
	res@cnLinesOn = True
	res@cnMinLevelValF  = 900.
	res@cnMaxLevelValF  = 1060.
	res@cnLevelSpacingF =  4.

	; MSLP contour
	plot = gsn_csm_contour_map(wks,f->mslp(iTime,:)/100,res)
 
	ustr = "uzonal_"+suffix
	vstr = "umeridional_"+suffix
	; Special case for 10m winds. Different naming convention for components.
	if (field.eq."speed_10m")then
		ustr = "u10"
		vstr = "v10"
	end if
	; Regrid u and v wind components to lat-lon with ESMF_regrid function.
	; Based on Bill Skamarock's scripts in /glade/p/mmm/skamaroc/Spring_exp/Test_forecasts/Test_ortho

	
	; Check the version of NCL
	version = systemfunc("ncl -V")
	;if(version.ne."6.2.1") then
	;    print("You need to run NCL V6.2.1 to run ESMF_regridding. Try module load ncl/6.2.1. Stopping now...")
	;    exit
	;end if

	source_points_file = meshdir + "source_cells_"+domain+".nc"
	;---destination lat-lon mesh
	dlat = 0.25
	dlon = 0.25
	stride = 7
	lat_north =  60.
	lat_south =   0.
	if (domain .eq. "al".or.domain.eq."AL") then
		lon_west = -100.
		lon_east =  -10.
	end if
	if (domain .eq. "ep".or.domain.eq."EP") then
		lon_west = -180.
		lon_east =  -90.
	end if
	if (domain .eq. "wp" .or. domain.eq."WP") then
		lon_west =   80.
		lon_east =  180.
	end if
	if (domain .eq. "test") then
		lon_west =   90.
		lon_east =  150.
	end if

 	lonCell = res@sfXArray
 	latCell = res@sfYArray

	nlat = floattointeger((lat_north-lat_south)/dlat) + 1
	nlon = floattointeger((lon_east-lon_west)/dlon) + 1

	rlatCell = new( (/nCells/), double )
	rlonCell = new( (/nCells/), double )

	; Find all the mesh points that fall within your box.
	; Save their lats and lons in rlatCell and rlonCell.
	; Use the premade file if it exists.
	if(isfilepresent(source_points_file)) then

		pf = addfile(source_points_file,"r")
		cell_idx = pf->cell_idx
		print(" finished reading "+source_points_file)
		icnt = pf->icnt
		rlatCell(0:icnt-1) = latCell(cell_idx(0:icnt-1))
		rlonCell(0:icnt-1) = lonCell(cell_idx(0:icnt-1))
		dst_lat = pf->dst_lat 
		dst_lon = pf->dst_lon

	else

		icnt=0
		cell_idx = new( (/nCells/), integer)
		dst_lat = new((/nlat,nlon/),float)
		dst_lon = new((/nlat,nlon/),float)

		do j=0,nlat-1
		do i=0,nlon-1
			dst_lat(j,i) = lat_south + j * dlat
			dst_lon(j,i) = lon_west + i * dlon
		end do
		end do
		lat1     = min(dst_lat) - 1. 
		lat2     = max(dst_lat) + 1.
		lon1     = min(dst_lon) - 1.
		lon2     = max(dst_lon) + 1.

		do i=0,nCells-1
			if(lonCell(i).gt.180.) then
			  lonCell(i)=lonCell(i)-360.
			end if

			if (latCell(i).ge.lat1) then
			if (latCell(i).le.lat2) then
			if (lonCell(i).ge.lon1) then
			if (lonCell(i).le.lon2) then

			  rlatCell(icnt) = latCell(i)
			  rlonCell(icnt) = lonCell(i)
			  cell_idx(icnt) = i
			  icnt = icnt+1

			end if
			end if
			end if
			end if

		end do

		pf = addfile(source_points_file,"c")
		pf->cell_idx = cell_idx
		pf->icnt = icnt
		pf->dst_lat = dst_lat
		pf->dst_lon = dst_lon
	end if
	print ("number of Cells in "+domain+" ::"+icnt)

	;---Set up regridding options
	Opt                   = True
	;---"bilinear" is the default. "patch" and "conserve" are other options.
	Opt@InterpMethod      = "bilinear" 

	Opt@SrcGridLat        = rlatCell(0:icnt-1) 
	Opt@SrcGridLon        = rlonCell(0:icnt-1)
	Opt@SrcRegional       = True   
	;Opt@SrcMask2D         = where(.not.ismissing(var),1,0) ; Necessary if has missing values.

	Opt@DstGridLat        = dst_lat
	Opt@DstGridLon        = dst_lon
	Opt@DstRegional       = True 

	Opt@ForceOverwrite    = False
	Opt@PrintTimings      = False
	Opt@Debug             = False
	Opt@NoPETLog          = True
	Opt@RemovePETLog      = True

	;Opt@SrcTriangularMesh = True

	Opt@WgtFileName       = meshdir + "esmf_wgt_"+domain+".nc"
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
	end if
	Opt@DstFileName       = meshdir + "esmf_dst_"+domain+".nc"
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
	end if
	Opt@SrcFileName       = meshdir + "esmf_src_"+domain+".nc"
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
	end if

	; U stride
	u := f->$ustr$(iTime,::stride)
	; Extract cells within domain limits.
	u := u(cell_idx(0:icnt-1))
	u := ESMF_regrid(u,Opt)
	u@lat2d = dst_lat
	u@lon2d = dst_lon
	
	; V
	v := f->$vstr$(iTime,::stride)
	; Extract cells within domain limits.
	v := v(cell_idx(0:icnt-1))
	v := ESMF_regrid(v,Opt)
	v@lat2d = dst_lat
	v@lon2d = dst_lon
	
	print("done regridding u & v wind")

	; Cosmetic changes for wind barbs
	vres = True
	vres@gsnDraw = False
	vres@gsnFrame = False
	vres@vcRefLengthF    = 0.024
	vres@vcGlyphStyle = "WindBarb"
	vres@vcPositionMode = "ArrowHead"
	vres@vcMinDistanceF = 0.030
	vres@vcRefAnnoOn = False
	vres@vcWindBarbLineThicknessF = 1.6
	vres@vcWindBarbScaleFactorF = 1.94384
	plot_ov = gsn_csm_vector(wks,u,v,vres)
	overlay(plot,plot_ov)

	draw(plot)
	frame(wks)
	print("processing success")

end

