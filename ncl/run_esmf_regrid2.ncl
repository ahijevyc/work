load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

undef("run_ESMF_regrid")
function run_ESMF_regrid (domain:string,ifile:file,field:numeric)

; input - 
;  domain - string (e.g. "al", "global")
;  ifile  - file   (init.nc usually)
;  field  - numeric array (field to plot)

; ifile must contain variables "latCell" and "lonCell" (or "latVertex" and
; "lonVertex" in the case of a vertex-based field).
; Usually this is "init.nc".

; Old version had a double-nested loop to find cell_idx indices within the destination
; grid and saved them to an external file source_cell.nc. But I take care of it with 
; a quick and simple boolean array. Otherwise src, wgt, and dst external files
; should be the same as old version. I also renamed the external files, removing the
; "esmf_" prefix and adding the "stride" count. 

; There are some helpful notes below if you have trouble making new grids.
; You must have permission to write in the current directory, in the external
; file directory, in the external files themselves. And you might need to 
; setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects_cheyenne/
; so the mpas_filter_cells and mpas_filter_vertices routines are defined. 

begin

	; Check the version of NCL
	version = get_ncl_version()
	print("run_ESMF_regrid: "+domain+" domain. "+version)

	if(isatt(domain,"meshdir"))then
		dir = domain@meshdir + "/"
	end if
	if(.not.isvar("dir"))then
		dir="./"
	end if
	;---destination lat-lon mesh
	dlat = 0.25
	dlon = 0.25

	stride = 12 ; default

	res = True

	; Function set_res_sf() is defined in get_field_res.ncl.
	; It assigns lonCell and latCell to sfXArray and sfYArray, respectively.
	; Works for cell or vertex based fields. Allows for stride (>1 to skip points).
	res = set_res_sf(res, ifile, field, stride)
 	lonCell = res@sfXArray	
 	latCell = res@sfYArray

    ; map to -180 - 180 
    if(max(lonCell).gt.180.) then
        lonCell = where(lonCell.gt.180,lonCell-360.,lonCell)
    end if

    ; Estimate lat/lon boundaries of destination grid
    ; from projection attributes defined in set_res_mp()
    bres = True
    bres = set_res_mp(bres, domain)
    lat_south = max((/-90, bres@mpMinLatF - 5/))
    lat_north = min((/ 90, bres@mpMaxLatF + 5/))
    lon_west  = max((/-180,bres@mpMinLonF - 25/))
    lon_east  = min((/ 180,bres@mpMaxLonF + 25/))

	nlat = tointeger((lat_north-lat_south)/dlat) + 1
	nlon = tointeger((lon_east-lon_west)/dlon) + 1

;---Create the destination lat/lon grid
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


;---Set up regridding options
    Opt                   = True
;---"bilinear" is the default. "patch" and "conserve" are other options.
    Opt@InterpMethod      = "bilinear"

    Opt@SrcGridLat        = latCell(ibox)
    Opt@SrcGridLon        = lonCell(ibox)
    Opt@SrcGridType       = "unstructured"
	Opt@SrcRegional       = True   

	Opt@DstGridLat        = dst_lat(:,0)  ; why did I define a 2d array in the first place?
	Opt@DstGridLon        = dst_lon(0,:)
	Opt@DstGridType       = "rectilinear"
	Opt@DstRegional       = True 

    ; If you get an error ESMF_regrid_gen_weights: could not find ESMF_RegridWeightGen executable
    ; you probably don't have write permission in the current working directory. 
    ; You need this because the ncl ESMF script tests with ESMF_RegridWeightGen --help, which 
    ; requires write permission for PET log file (even if Opt@NoPETLog = True). 

    ; If you get "invalid Src File", when making the Wgt file,
    ; try removing the Src and Dst file, and rerun. 
	Opt@ForceOverwrite    = False
	Opt@PrintTimings      = False
	Opt@Debug             = False
	Opt@NoPETLog          = True
	Opt@RemovePETLog      = True

    esmf_suffix = "_" + domain + "." + tostring(stride) + ".nc"
	Opt@WgtFileName       = dir + "wgt" + esmf_suffix
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
		print("run_ESMF_regrid: SkipWgtGen")
	end if
	Opt@DstFileName       = dir + "dst" + esmf_suffix
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
		print("run_ESMF_regrid: SkipDstGrid")
	end if
	Opt@SrcFileName       = dir + "src" + esmf_suffix
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
		print("run_ESMF_regrid: SkipSrcGrid")
	end if

    ; Apply stride
    if (isdim(field,"Time")) then
        tmp := field(0,::stride)
    else
        tmp := field(::stride)
    end if

	; Extract cells within domain limits.
    ; Don't know why this must be done after stride application.
    tmp := tmp(ibox)

    tmp2 := ESMF_regrid(tmp,Opt)   ; regridding 


    ; If you change the domain in get_field.ncl you might get this warning.
    ;(0)	is_valid_latlon2d_attr: Warning: The 'lon2d' attribute must either be
    ;(0)	the same dimension sizes as the data, or one element larger in both directions.
    ;(0)	Your data will most likely not be overlaid on the map correctly.
    ; 
    ; Deal with changed domain. Redo if dimsizes don't match before bad overlay is drawn.
    if(any(dimsizes(tmp2).ne.dimsizes(dst_lat)))then
        print("domain "+domain+" changed. Redoing Wgt,Dst,Src files")
        Opt@ForceOverwrite = True
		Opt@SkipWgtGen = False
		Opt@SkipDstGrid = False
		Opt@SkipSrcGrid = False
        tmp2 := ESMF_regrid(tmp,Opt)   ; regridding 
    end if

    tmp2@lat2d = dst_lat
    tmp2@lon2d = dst_lon

	return(tmp2)
end

