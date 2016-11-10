load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/p/work/ahijevyc/ncl/cd_inv_string.ncl"

srcFileName = "/glade/scratch/ahijevyc/VSE/1km_pbl1/2007021312/post_AGAIN/fhr_0/WRFTWO00.nc"
dstFileName = "/glade/scratch/ahijevyc/VSE/3km_pbl1/2007021312/post_AGAIN/fhr_0/WRFTWO00.nc"

sfile=addfile(srcFileName,"r")
dfile=addfile(dstFileName,"r")

var = sfile->PVORT_320K
src_lat2d = sfile->latitude
src_lon2d = sfile->longitude

dst_lat2d = dfile->latitude
dst_lon2d = dfile->longitude
dst_nlat = dimsizes(dst_lat2d(:,0))
dst_nlon = dimsizes(dst_lat2d(0,:))

;---Set up options for regridding
Opt                = True

Opt@SrcFileName    = "/glade/scratch/ahijevyc/VSE/ESMF_source_1km_on_3km.nc"
Opt@WgtFileName    = "/glade/scratch/ahijevyc/VSE/ESMF_weights_1km_on_3km.nc"
Opt@DstFileName    = "/glade/scratch/ahijevyc/VSE/ESMF_destination_1km_on_3km.nc"

Opt@SrcGridLat     = src_lat2d     ; source grid
Opt@SrcGridLon     = src_lon2d
Opt@DstGridLat     = dst_lat2d     ; destination grid
Opt@DstGridLon     = dst_lon2d

Opt@SrcRegional    = True          ; Necessary if grids
Opt@DstRegional    = True          ; are regional

Opt@InterpMethod   = "conserve"    ; "patch", "conserve"

if(fileexists(Opt@WgtFileName))then
	Opt@SkipSrcGrid = True
	Opt@SkipDstGrid = True
	Opt@SkipWgtGen  = True
else
	Opt@SkipSrcGrid = False
	Opt@SkipDstGrid = False
	Opt@SkipWgtGen  = False
end if


Opt@ForceOverwrite = True          ; Optional, but recommended.
Opt@PrintTimings   = False         ; Optional.
Opt@Debug          = False         ; Optional

var_regrid = ESMF_regrid(var,Opt)      ; Do the regridding

;fils = systemfunc("ls /glade/scratch/ahijevyc/VSE/1km_pbl2/20*12/post_AGAIN/fhr_*/WRFTWO*.nc")
fils := systemfunc("ls /glade/p/mmm/schwartz/VSE/1km_pbl1/20*12/wrf/join/vse_d01.*:00:00.nc") ; remove "join" part of path afterwards.
do ifile= 0,dimsizes(fils)-1 
	fil = fils(ifile)
	; Make output same as input filename except with "3km_" prepended. Same directory too.
	;ofile = systemfunc("dirname "+fil)+"/3km_"+systemfunc("basename "+fil)
	; Put in separate "1km_on_3km_pbl" directory. Keep same filename. Easier to process later.
	rest = str_get_cols(fil,str_index_of_substr(fil,"pbl",1)+3,-1)
	ofile = "/glade/scratch/ahijevyc/VSE/1km_on_3km_pbl"+rest
	print("ofile="+ofile)
	if(isfilepresent(ofile))then
		print("found "+ofile+". skipping.")
		continue
		;system("rm -v "+ofile)
	end if
	print("opening "+fil)
	i=addfile(fil,"r")
	fields = getfilevarnames(i)
	print(fields)

	o = addfile(ofile, "c")
	do ifield=0,dimsizes(fields)-1
		field = fields(ifield)
		var := i->$field$
		vardims := getvardims(var)
		; Some files have horizontal coordinates "x" and "y"; some "west_east" and "south_north". I don't think it matters.
		; convert everything to "x" and "y"
		if(any("x".eq.vardims).and.any("y".eq.vardims).or.any("south_north".eq.vardims).and.any("west_east".eq.vardims))then
			print(field)
			;printVarSummary(var)
			ovar := ESMF_regrid(var,Opt)
			copy_VarCoords(dfile->PVORT_320K,ovar) ; copy "x" and "y" coordinates
			delete_VarAtts(ovar&time,-1) ; must remove attributes of time coordinate variable because it comes from dfile. We overwrite the number later.
			o->$field$ = ovar
		end if
	end do
	; Essential - or else time will be Feb 13 2007 from dstFile, due to copy_VarCoords() above.
	if(isfilevar(i,"time"))then
		print("getting time from "+fil)
		time := i->time
	end if
	if(isfilevar(i,"Times"))then
		time := cd_inv_string(tostring(i->Times))
	end if
	print(time)
	o->time = time
end do
