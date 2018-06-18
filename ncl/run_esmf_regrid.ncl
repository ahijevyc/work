load "/glade/p/work/mpasrt/rt2015/ncl/get_field_res.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

undef("run_ESMF_regrid")
function run_ESMF_regrid (domain:string,ff:file,field:numeric)
	; ff must contain variables "latCell" and "lonCell" (or "latVertex" and
	; "lonVertex" in the case of a vertex-based field).
	; Usually this is "init.nc".
 
begin

	; Check the version of NCL
	version = get_ncl_version()
	print("run_ESMF_regrid: "+domain+" domain. "+version)

	; In the future, to accomodate different meshes, we may want to 
	; read something unique about ff and use a unique directory based 
	; on it. 
	; Here's a check for the new 15_3km mesh tested June 4 2015
	if (dimsizes(ff->latCell) .eq. 6488066) then
		dir = "/glade/p/work/mpasrt/rt2015/esmf_regrid.pecan/"
	end if
	; override the above "educated guesses" for the mesh location.
	if(isatt(domain,"meshdir"))then
		dir = domain@meshdir + "/"
	end if
	if(.not.isvar("dir"))then
		dir="./"
	end if
	source_points_file = dir + "source_cells_"+domain+".nc"
	;---destination lat-lon mesh
	dlat = 0.25
	dlon = 0.25

    span_dateline = False ; span dateline?
	stride = 3 ; default
	if (domain .eq. "east") then
		lon_west = -110.
		lon_east = -60.
		lat_south = 20.
		lat_north = 55.
		stride = 6
	end if
	if (domain .eq. "central") then
		lon_west = -112.
		lon_east = -80.
		lat_south = 28.
		lat_north = 46.
		stride = 3
	end if
	if (domain .eq. "us") then
		lon_west = -161.
		lon_east = -39.
		lat_south = 5.
		lat_north = 70.
		stride = 12 
	end if
	if (domain .eq. "conus") then
		lon_west = -135.
		lon_east = -60.
		lat_south = 20.
		lat_north = 55.
		stride = 6 
	end if
	if (domain .eq. "global") then
		lon_west = -180.
		lon_east =  180.
		lat_south = -90.
		lat_north =  90.
		stride = 10
	end if
	if (domain .eq. "west") then
		lon_west = -135.
		lon_east = -85.
		lat_south = 20.
		lat_north = 55.
		stride = 6
	end if
	if (domain .eq. "al".or.domain.eq."AL") then
		lon_west = -110.
		lon_east =  -10.
		lat_south =   0.
		lat_north =  60.
		stride = 8
	end if
	if (domain .eq. "ep".or.domain.eq."EP") then
		lon_west = -180.
		lon_east =  -90.
		lat_south =   0.
		lat_north =  60.
		stride = 7
	end if
	if (domain .eq. "wp" .or. domain.eq."WP" .or. domain.eq."Lionrock0") then
        span_dateline = True
        ; longitude 0-360, like lonCell
		lon_west  =   80.
		lon_east  =  190.
		lat_south =    0.
		lat_north =   65.
		stride    =    9
	end if


	res = True

	; Function get_res_sf() is part of get_field_res.ncl.
	; It assigns lonCell and latCell to sfXArray and sfYArray, respectively.
	; Allows for cell or vertex based fields. Allows for stride (>1 to skip points).
	res = set_res_sf(res, ff, field, stride)
 	lonCell = res@sfXArray	
 	latCell = res@sfYArray

	nCells = dimsizes(latCell)

	nlat = floattointeger((lat_north-lat_south)/dlat) + 1
	nlon = floattointeger((lon_east-lon_west)/dlon) + 1

	; print(" nlat and nlon "+nlat+" "+nlon)

	rlatCell = new( (/nCells/), double )
	rlonCell = new( (/nCells/), double )

	; Find all the mesh points that fall within your box.
	; Save their lats and lons in rlatCell and rlonCell.
	; Use the premade file if it exists.
	if(isfilepresent(source_points_file)) then

		pf = addfile(source_points_file,"r")
		cell_idx = pf->cell_idx
		;print(" finished reading "+source_points_file)
		icnt = pf->icnt
		;print(" icnt = "+icnt)
		rlatCell(0:icnt-1) = latCell(cell_idx(0:icnt-1))
		rlonCell(0:icnt-1) = lonCell(cell_idx(0:icnt-1))
		dst_lat = pf->dst_lat 
		dst_lon = pf->dst_lon

	else
        print("run_esmf_regid: did not find src points file "+source_points_file)
        ; On Jul 18, 2017 ahijevych remade the wp domain. He needed to erase the src dst, etc. files
        ; and load module ncl/6.3.0 (not default 6.4.0)
    	if(version.ne."6.3.0") then
    	    print("You might need to run NCL V6.3.0 to run ESMF_regridding. Try module load ncl/6.3.0. Stopping now...")
    	    ;exit
    	end if

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
            ; map to -180 - 180 unless dateline is spanned.
            ; If dateline is spanned keep lonCell in 0-360 range.
			if(.not.span_dateline.and.lonCell(i).gt.180.) then
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

	;print(" lat min and max "+dst_lat(0,0)+" "+dst_lat(nlat-1,0))
	;print(" lon min and max "+dst_lon(0,0)+" "+dst_lon(0,nlon-1))
	;print ("number of Cells in "+domain+" ::"+icnt)

;==================================================================================

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

	Opt@WgtFileName       = dir + "esmf_wgt_"+domain+".nc"
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
	end if
	Opt@DstFileName       = dir + "esmf_dst_"+domain+".nc"
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
	end if
	Opt@SrcFileName       = dir + "esmf_src_"+domain+".nc"
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
	end if

	; Apply stride.
	if (isdim(field,"Time")) then
		tmp = field(0,::stride)
	else
		tmp = field(::stride)
	end if
	; Extract cells within domain limits.
	tmp1 = tmp(cell_idx(0:icnt-1))
	delete(tmp)
	tmp = ESMF_regrid(tmp1,Opt)
	delete(tmp1)
	tmp@lat2d = dst_lat
	tmp@lon2d = dst_lon
	return(tmp)
end

