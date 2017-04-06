;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;==========================================================================

; written by David Ahijevych global precipitation plots
; First make average rainnc, rainc files.
; For example,
; foreach f (/glade/p/nmmm0024/wp/2015*)
; 	cd $f
; 	forecast_hour_links.pl diag*
; end
; ncea -O -v rainnc,rainc,xtime /glade/p/nmmm0024/wp/2015*00/f000.nc f000.nc


begin

	field = "rain"
	mesh = "ep"
	workdir = "/glade/p/work/ahijevyc/mpas_plots/"+mesh+"/"
	fname_pattern = "f???.nc"
	suffix = "6h"
	stride = 1 ; plot every "stride" files.
	domain = "global"

	;======================================================================= 
	; current working directory is set in calling script 
	filei = workdir + "init.nc"
	if (.not.isfilepresent(filei))then
		print(filei+" not present. make sym link?")
		exit
	end if
	; Open initialization file and read lat/lon/cell information.
	ff = addfile(filei,"r")
	verticesOnCell = ff->verticesOnCell
	cellsOnCell    = ff->cellsOnCell
	nEdgesOnCell   = ff->nEdgesOnCell
	latCell        = ff->latCell
	dv             = dimsizes(verticesOnCell)
	maxEdges       = dv(1)
	nCells         = dimsizes(nEdgesOnCell)
	nVertices      = dimsizes(ff->latVertex)
	print("done reading cell and vertex info")

	; Get a list of forecast diagnostics files. 
	files = systemfunc (" ls -1 " + workdir + fname_pattern)
	print(files)
	nfiles = dimsizes(files)
	;loop over the files array.
	do ifile = 0, nfiles-1, stride
		f = addfile(files(ifile),"r")
		print("opened "+files(ifile))
		iTime = 0
		
		hr = str_get_cols(systemfunc("basename "+files(ifile)),1,3)
		dt = -1*stringtodouble(str_get_cols(suffix,0,-2))
		hr0 = sprintf("%03.0f",stringtodouble(hr)+dt)
		if (tointeger(hr0).lt.0)then
			continue
		end if
		ofile = workdir+mesh+"_"+field+suffix+".f"+hr0+"-f"+hr+".png"
		; Uncomment to force a new image to be made.
		; system("/bin/rm -f " + ofile)
		; Skip existing output files. 
		if(fileexists(ofile))
			print(ofile+" exists. skipping.")
			continue
		end if
		print("output file: "+ofile)
		wks_type = "png"
		wks = gsn_open_wks(wks_type,ofile)

		; Derive rainfall.
		; Subtract the past accumulation from the current accumulation.
		; If current lead time is shorter than accumulation interval, then past accumulation is assumed to be 0.
		oldfile = workdir + "f"+hr0+".nc"
		if (field.eq."rain")then
			field_color_fill = f->rainc + f->rainnc
		else
			field_color_fill = f->$field$
		end if
		if (isfilepresent(oldfile))
			f0 = addfile(oldfile,"r")
			if (field.eq."rain")then
				field_color_fill = field_color_fill - f0->rainc - f0->rainnc
			else
				field_color_fill = field_color_fill - f0->$field$
			end if
			delete(f0)
		else
			print("oh no. couldn't find oldfile "+oldfile)
			exit
		end if
		; Coordinate variables get erased above, so restore them.
		copy_VarCoords(f->rainc,field_color_fill)
		print("min/max="+min(field_color_fill)+" "+max(field_color_fill))

		; Set plot resources.
		; get_field_res sets color table, filled contours, and plot labels based on field.
		res = get_field_res(wks, "compare rain to CMORPH", field_color_fill)
		; set_res_map defines map boundaries based on domain.
		res = set_res_mp(res, domain)
		res@mpCenterLonF = 180.
		res@mpMinLatF = -60.
		res@mpMaxLatF =  60.

		res@tiMainString    = mesh + " mesh  MPAS "+hr0+"-"+hr+"h fcst"
		res@tiMainFontHeightF = 0.015


		; Make sure field_color_fill is defined by now.
		if(.not. isdefined("field_color_fill")) then 
			print("field_color_fill "+field+" is not defined")
			exit
		end if

		; Strip time dimension.  It is always size-1 anyways, as far as Ahijevych knows.
		tmp = field_color_fill(iTime,:)
		delete(field_color_fill)
		field_color_fill = tmp
		print("min/max="+min(field_color_fill)+" "+max(field_color_fill))
		delete(tmp)

		if (isatt(res,"nSmoothPasses")) then
			delete(res@nSmoothPasses)
		end if

		; set_res_sf sets sfXArray and sfYarray (1-D lats and lons needed for plotting a mesh)
		; works with cell-based or vertex-based fields.
		res = set_res_sf(res,ff,field_color_fill,1)
		; Create plot
		plot = gsn_csm_contour_map(wks,field_color_fill,res)
		print("done creating background of "+field)
		delete(f)
		delete(field_color_fill)
		draw(plot)
		print("done drawing plot object")
		delete(plot)
		frame(wks)
		system("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+ofile)
	end do ; files loop
	delete(ff)
	print("processing success")

end

