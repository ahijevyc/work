load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
;==========================================================================

; written by David Ahijevych
; MSLP contour and windbarbs
; Regrid u and v wind components to lat-lon with ESMF_regrid function.

begin

    ; contour field
	field = "speed_10m"
	suffix = "10m"; To be appended to "uzonal_" and "umeridional_". could be "700hPa"

	init_date = "2018060100"
	fname = "diag.2018-06-01_18.00.00.nc"

	; String name for plotting domain
	domain = "us"

    ; String name for MPAS mesh
    mesh = "uni"

	; Directory that holds (or will hold) esmf weight, destination, and source files for MPAS mesh
    ; This script will create these 3 files if they haven't been created already.
    ; End with "/".
    ; 
	meshdir = "/glade/work/mpasrt/rt2015/esmf_regrid."+mesh+"/"
	meshdir = "./"

    ; Directory with initialization file "init.nc".
    ; init.nc must contain variables "latCell" and "lonCell" (or "latVertex" and
    ; "lonVertex" in the case of a vertex-based field).
    ; 
	diri = "/glade/scratch/mpasrt/"+mesh+"/"+init_date+"/"


	ifile = diri+"init.nc"
	if (.not.isfilepresent(ifile))then
		print(ifile+" not present")
		exit
	end if

	; Open initialization file and read lat/lon/cell information.
	ff = addfile(ifile,"r")
	cellsOnCell    = ff->cellsOnCell
	nEdgesOnCell   = ff->nEdgesOnCell
	edgesOnCell    = ff->edgesOnCell
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
	res@mpProjection      = "CylindricalEquidistant"
	res@mpDataBaseVersion = "MediumRes" 
	res@mpLimitMode       = "LatLon"
    ; Plotting bounds
	res@mpMinLatF =   15.
	res@mpMaxLatF =   50.
	res@mpMinLonF = -100.
	res@mpMaxLonF =  -55.
	; set sfXArray and sfYarray (1-D lats and lons needed for plotting a mesh)
	RAD2DEG = 180.0d/(atan(1)*4.0d)
	res@sfXArray = ff->lonCell * RAD2DEG
	res@sfYArray = ff->latCell * RAD2DEG
  
	res@gsnFrame  = False
	res@cnFillOn  = False
	res@cnLevelSelectionMode = "ManualLevels"
	res@cnLinesOn = True
	res@cnMinLevelValF  =  900.
	res@cnMaxLevelValF  = 1060.
	res@cnLevelSpacingF =    4.

	; MSLP contour
	plot = gsn_csm_contour_map(wks,f->mslp(iTime,:)/100,res)
 
	ustr = "uzonal_"+suffix
	vstr = "umeridional_"+suffix
	; Special case for 10m winds. Different naming convention for components.
	if (field.eq."speed_10m")then
		ustr = "u10"
		vstr = "v10"
	end if

	
 	lonCell = res@sfXArray
 	latCell = res@sfYArray

    ; Estimate lat/lon boundaries of destination grid
    ; from projection attributes defined in set_res_mp()
    lat_south = max((/ -90, res@mpMinLatF -  5/))
    lat_north = min((/  90, res@mpMaxLatF +  5/))
    lon_west  = max((/-180, res@mpMinLonF - 25/))
    lon_east  = min((/ 180, res@mpMaxLonF + 25/))

	;---destination lat-lon mesh
	dlat = 0.25
	dlon = 0.25

	nlat = floattointeger((lat_north-lat_south)/dlat) + 1
	nlon = floattointeger((lon_east-lon_west)/dlon) + 1
	print(" nlat and nlon "+nlat+" "+nlon)

    ; Longitudes should range from -180 - 180, not 0-360.
    ; Don't remember if this was ncl requirement or what. 
    if(max(lonCell).gt.180.) then
        lonCell = where(lonCell.gt.180,lonCell-360.,lonCell)
    end if


    ; Create destination lat/lon grid.
    dst_lat = new((/nlat,nlon/),float)
    dst_lon = new((/nlat,nlon/),float)

    do j=0,nlat-1
    do i=0,nlon-1
        dst_lat(j,i) = lat_south + j * dlat
        dst_lon(j,i) = lon_west  + i * dlon
    end do
    end do

    ; Indices of cells within domain limits. Make this script run faster.
    ibox = ind(latCell.ge.min(dst_lat) .and. latCell.le.max(dst_lat) .and. \
               lonCell.ge.min(dst_lon) .and. lonCell.le.max(dst_lon) )

    if (all(ismissing(ibox))) then
        print(lon_west)
        print(lon_east)
        printMinMax(lonCell,False)
        print("no cells in box")
        exit
    end if

	print(" lat min and max "+dst_lat(0,0)+" "+dst_lat(nlat-1,0))
	print(" lon min and max "+dst_lon(0,0)+" "+dst_lon(0,nlon-1))

;==================================================================================

;---Set up regridding options
    Opt                   = True
;---"bilinear" is the default. "patch" and "conserve" are other options.
    Opt@InterpMethod      = "bilinear"

    ; Extract latCell and lonCell from cells in domain.
	Opt@SrcGridLat        = latCell(ibox)
	Opt@SrcGridLon        = lonCell(ibox)
    Opt@ElementVertices   = edgesOnCell(ibox,:) ; Supposed to speed things up, but no effect
	Opt@SrcGridType       = "unstructured"
	Opt@SrcRegional       = True 

	Opt@DstGridLat        = dst_lat(:,0)
	Opt@DstGridLon        = dst_lon(0,:)
	Opt@DstGridType       = "rectilinear"
	Opt@DstRegional       = True 

    ; If you get "invalid Src File", when making the Wgt file,
    ; try removing the Src and Dst file, and rerun. 
	Opt@ForceOverwrite    = False
	Opt@PrintTimings      = False
	Opt@Debug             = True
	Opt@NoPETLog          = True
	Opt@RemovePETLog      = True

    esmf_suffix = "_" + domain + ".nc"
	Opt@WgtFileName       = meshdir + "wgt" + esmf_suffix
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
	end if
	Opt@DstFileName       = meshdir + "dst" + esmf_suffix
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
	end if
	Opt@SrcFileName       = meshdir + "src" + esmf_suffix
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
	end if


	; Extract iTime and cells in domain.
	u := f->$ustr$(iTime,ibox)
	print("regridding u wind")
	u := ESMF_regrid(u,Opt)
	
	; Extract iTime and cells in domain.
	v := f->$vstr$(iTime,ibox)
    ; Now that u is regridded, Wgt Dst and Src files should be available.
    ; Note WgtGen vs. DstGrid and SrcGrid ("Gen" vs "Grid")
    Opt@SkipWgtGen  = True
    Opt@SkipDstGrid = True
    Opt@SkipSrcGrid = True
	print("regridding v wind")
	v := ESMF_regrid(v,Opt)
	
	print("done regridding u & v wind")


	; Cosmetic changes for wind barbs
	vres = True
	vres@gsnDraw  = False
	vres@gsnFrame = False
	vres@vcRefLengthF    = 0.02
	vres@vcGlyphStyle   = "WindBarb"
	vres@vcPositionMode = "ArrowHead"
	vres@vcMinDistanceF = 0.02
	vres@vcRefAnnoOn    = False
	vres@vcWindBarbLineThicknessF = 1.5
	vres@vcWindBarbScaleFactorF = 1.94384
	plot_ov = gsn_csm_vector(wks,u,v,vres)
	overlay(plot,plot_ov)

	draw(plot)
	frame(wks)
	print("processing success")

end

