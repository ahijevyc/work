;==========================================================================
; This NCL script to be called by run_field_and_contour_ncl.csh
;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/work/ahijevyc/ncl/run_esmf_regrid2.ncl"
load "/glade/work/ahijevyc/ncl/xtime.ncl"
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/derived_fields.ncl"
;==========================================================================

; written by David Ahijevych for SPC Spring Experiment 2015
; Plot a color-filled contour background with optional windbarbs and optional 
; line contour.

; "field" variable is the color-filled background
; "domain" variable sets the domain
; "suffix" can be a shear layer, a pressure level, an accumulation interval.
;	It is part of the "field" string variable.
; "prefix" is the part of the "field" variable before the suffix.
; "contour_string" is the line contour field.
;

begin

	; environmental variables set by run_create_ncl.csh
	init_date = getenv("init_date")
	fname_pattern = getenv("fname_pattern")
	field = getenv("ncl_field")
	domain = getenv("ncl_domain")
	prefix = getenv("prefix")
	suffix = getenv("suffix")
	field@project = getenv("project")
	contour_string = getenv("ncl_contour1")

	; Set defaults if environmental variables were not set by run script.
	; Useful for debugging on command line without needing the run script.
	; i.e. "ncl field_and_contour.ncl"
	if(ismissing(field)) then
		field = "shear_0_1km"
	end if
        if(ismissing(contour_string)) then
		contour_string = ""
	end if
	if(ismissing(init_date)) then
		init_date = "2015062000"
	end if
	if(ismissing(fname_pattern)) then
		fname_pattern = "diag*.nc"
	end if
	if(ismissing(domain)) then
		domain = "central"
	end if
	if(ismissing(prefix)) then
		prefix = "shear"
	end if
	if(ismissing(field@project)) then
		field@project = "spring_exp" ; hur15, hur15ep, hur15al
	end if
	if(ismissing(suffix)) then
		suffix = "0_1km"
	end if

	; sanity check
	if(ismissing(str_match(field,prefix)).or.ismissing(str_match(field,suffix)))then
		print("mismatch between field, prefix, and suffix: "+field+" "+prefix+" "+suffix)
		exit
	end if
	print(init_date + " " + domain + " " + field + " " + prefix + " " + suffix + " " + fname_pattern + " " + contour_string)

	; plot_windbarb attribute passed to get_field_res() so long_name (gsnLeftString) can be adjusted accordingly.
	field@plot_windbarb = False
	if ((str_get_cols(suffix,-3,-1).eq."hPa" .or. field.eq."cape" .or. field.eq."thetae" .or. field.eq."t2m" .or. str_get_cols(field,0,4).eq."shear" .or. field.eq."dewpoint_surface".or. field.eq."speed_10m" .or. str_get_cols(field,0,2).eq."srh" .or. field.eq."mslp" .or. field.eq."rainnc3h" .or. field.eq."rainc3h") .and. domain .ne."global") then
		field@plot_windbarb = True 
	end if


	;======================================================================= 
	; current working directory is set in calling script, run_field_and_contour_ncl.csh 
	; Or the current working directory may be a testing place...
	diri = "./"
	filei = "init.nc"
	if (.not.isfilepresent(diri+filei))then
		print(diri+filei+" not present")
		exit
	end if
	; Open initialization file and read lat/lon/cell information.
	ff = addfile(diri+filei,"r")
	nEdgesOnCell   = ff->nEdgesOnCell
	nCells         = dimsizes(nEdgesOnCell)
	;print("done reading cell and vertex info")

	; Where terrain_mask = True, data are shown.
	; Used below to mask out data below pressure level.
	; 0 index is not for time, but vertical level
	terrain= ff->zgrid(:,0)

    ; ESMF mesh file location. Used for wind barbs. 
	domain@meshdir = "/glade/work/mpasrt/rt2015/esmf_regrid."+field@project
	resolution = ""
	if (nCells.eq.6848514) then
		resolution = "50-3km"
	end if
	if (nCells .eq. 6488066) then
		resolution = "15-3km"
	;	domain@meshdir = "/glade/work/mpasrt/rt2015/esmf_regrid.pecan"
	end if
	if (nCells .eq. 2621442) then
		resolution = "15km"
		domain@meshdir = "/glade/work/mpasrt/rt2015/esmf_regrid.uni"
	end if
	if (nCells .eq. 535554) then
		resolution = "60-15km"
		if(field@project.eq."hur15")then
			resolution = "WP "+resolution
		end if
		if(field@project.eq."hur15al")then
			resolution = "AL "+resolution
		end if
		if(field@project.eq."hur15ep")then
			resolution = "EP "+resolution
		end if
		if(field@project.eq."hur15us")then
			resolution = "US "+resolution
		end if
	end if
    ; If parent_id exists and is not empty, append it to meshdir with a period '.'
    ; This ensures the correct ESMF triangulation file is used for wind barbs.
    if(isatt(ff,"parent_id").and.ff@parent_id.ne."")then
        parent_id = str_split(ff@parent_id, str_get_nl)
        parent_id := parent_id(0) ; just the first item, no newlines.
        domain@meshdir = domain@meshdir + "." + parent_id
    end if
    print(domain)
    

	; Get a list of forecast diagnostics files. 
	files = systemfunc (" ls -1 " + str_join(diri + str_split(fname_pattern," ")," "))
	print(" ls -1 " + str_join(diri + str_split(fname_pattern," ")," "))
	print(files)
	nfiles = dimsizes(files)
	;loop over the files array.
	do ifile = 0, nfiles-1
		f = addfile(files(ifile),"r")
		print("opened "+files(ifile))
		iTime = 0
		xtime = str_strip(chartostring(f->xtime))
        ; Used to assume xtime from init file is the initialization time of the model.
        ; However, it may be an init.nc file from an arbitrary date (just for latCells, etc.)
        ; Instead use init_date and still use f->xtime from diagnostic file for valid time.
		hr = fhour_xtime(init_date,f)
		if(domain.eq."global")then
			if (mod(hr,6).ne.0) then
				; Skip to next file unless forecast hour is a multiple of 6.
				print("global. forecast hour not multiple of 6")
				continue
			end if
		end if
		ofile = diri+"plots/"+init_date+"/"+field@project+"."+field+"."+domain+".hr"+sprintf("%03.0f",hr)+".png"
		; Uncomment to force a new image to be made.
		; system("/bin/rm -f " + ofile)
		; Skip existing output files. 
		if(fileexists(ofile))
			print(ofile+" exists. skipping.")
			continue
		end if
		print("output file: "+ofile)
		wks_type = "png"
		wks_type@wkWidth = 1200; default 1024
		wks_type@wkHeight = 1200
		wks = gsn_open_wks(wks_type,ofile)


		; Read variable "field" from file.
		if (isfilevar(f,field)) then
			field_color_fill = f->$field$
		end if
		; Derive thickness
		if (prefix .eq. "thickness") then
			; get_thickness() returns pressure layer thickness
			field_color_fill = get_thickness(f,field,ff)
		end if
		; Derive wind shear
		if (prefix .eq. "shear") then
			; get_shear() returns wind shear
			field_color_fill = get_shear(f,suffix)
		end if
		; Derive wind speed
		if (prefix .eq. "speed") then
			; get_speed() returns wind speed
			field_color_fill = get_speed(f,suffix)
		end if
		; Derive thetae
		if (prefix .eq. "thetae") then
            ; Just found out q2 is specific humidity, not mixing ratio May 24, 2017.
            ; thetae function requires mixing ratio
			field_color_fill = thetae(f->th2m,f->q2,f->t2m)
		end if
		; Derive rainfall.
		if (str_get_cols(prefix,0,3).eq."rain") then
			; Subtract the past accumulation from the current accumulation.
			; If current lead time is shorter than accumulation interval, then past accumulation is assumed to be 0.
			dt = -1*stringtodouble(str_get_cols(suffix,0,-2))
			; f is the file variable; files(ifile) is the absolute path to the file.
			if (prefix.eq."rain") then
				field_color_fill = change_in_last_nhours(f,files(ifile),"rainc",dt) + change_in_last_nhours(f,files(ifile),"rainnc",dt)
				; Coordinate variables get erased above, so restore them.
				copy_VarCoords(f->rainc,field_color_fill)
			else
				field_color_fill = change_in_last_nhours(f,files(ifile),prefix,dt)
			end if
			print("min/max="+min(field_color_fill)+" "+max(field_color_fill))
		end if
		if (prefix .eq. "updraft_helicity_max".and.suffix.ne."") then
			field_color_fill = max_over_last_nhours(f,files(ifile),prefix,stringtodouble(str_get_cols(suffix,0,-2)))
		end if
		; Make sure field_color_fill is defined by now.
		if(.not. isdefined("field_color_fill")) then 
			print("field_color_fill "+field+" is not defined")
			exit
		end if
		;printVarSummary(field_color_fill)

		; Set plot and map resources.
		; get_field_res sets color table, filled contours, and plot labels based on field.
		; set_res_map defines map boundaries based on domain.
		res = get_field_res(wks, field, field_color_fill)
		res@tiMainString    = "MPAS "+resolution+" "+hr+"h fcst~C~Init: "+init_date+" UTC Valid: "+xtime+" UTC"
		res@tiMainFontHeightF = 0.015

		res = set_res_mp(res, domain)

		; Hack away time dimension.  It is always size-1 anyways, as far as Ahijevych knows.
		field_color_fill := field_color_fill(iTime,:)
		printMinMax(field_color_fill,False)
		printVarSummary(field_color_fill)
		print("avg="+sprintf("%f",avg(field_color_fill)))

		; grab the pressure-level height if it exists.
		; Used for masking
		if (isfilevar(f,"height_"+suffix)) then
			fstr = "height_"+suffix
			print("reading height")
			height = f->$fstr$(iTime,:)
		else
			height = default_fillvalue("double")
		end if

		; mask for pressure level fields. Use .le. instead of .lt. 
		if (min(height-terrain).le.0) then
            ; Terrain is cell-based. field_color_fill must be too, in order for mask to work.
            if (any(isdim(field_color_fill, "nCells"))) then
	    		field_color_fill = mask(field_color_fill,height.gt.terrain,True)
            end if
		end if

		; set_res_sf sets sfXArray and sfYarray (1-D lats and lons needed for plotting a mesh)
		; works with cell-based or vertex-based fields. As of Jul 1, 2016 it also smoothes.
		res = set_res_sf(res,ff,field_color_fill,1)
		; Create plot
		plot = gsn_csm_contour_map(wks,field_color_fill,res)
		print("done creating background of "+field)
	  
		; If a contour field is called for...
		if(contour_string.ne."")then
			if (isfilevar(f,contour_string)) then
				print("reading contour1 "+contour_string)
				contour1 = f->$contour_string$(iTime,:)
			end if   
			if (str_get_cols(contour_string,0,9).eq."thickness_") then
				; Overlay MSLP first
				contour1 = f->mslp(iTime,:)
				sres := get_res_cn(domain,"mslp",contour1)
				sres  = set_res_sf(sres, ff, contour1, 1)
				sres@cnLineDashPattern = 1
				sres@cnLineThicknessF = 1.
				sres@cnInfoLabelZone = 3
				sres@gsnLeftString = ""
				sres@gsnRightString = ""
				plot_ov := gsn_csm_contour(wks,contour1,sres)
				overlay(plot,plot_ov)
				contour1 := get_thickness(f, contour_string, ff)
				contour1 := contour1(iTime,:)
			end if
			; get_res_cn sets contour resources based on domain and field
			sres := get_res_cn(domain,contour_string,contour1)
			sres  = set_res_sf(sres,ff,contour1,1)
			; don't use := to assign masked contour1; that will delete its units and long_name attributes.
			contour1 = mask(contour1,height.gt.terrain,True)
			plot_ov := gsn_csm_contour(wks,contour1,sres)
			overlay(plot,plot_ov)
			print("done overlaying "+contour_string+" contour")
		end if
	 
		; If a vector field is called for...
		to_subtract = False
		; Take last 3 characters of suffix if it ends in "km". 
		; This can be a shear layer string. We will subract surface wind.
		if(str_get_cols(suffix,-2,-1) .eq. "km") then
			; This is a shear vector. 
			suffix = str_get_cols(suffix,-3,-1)
			to_subtract = True
		end if
		; Special case for 0-3km SRH. Plot 0-6km wind shear barbs.
		if (field.eq."srh_0_3km".or.field.eq."cape")then
			suffix = "6km"
			to_subtract = True
		end if
		ustr = "uzonal_"+suffix
		vstr = "umeridional_"+suffix
		; Special case for 10m winds. Different naming convention for components.
		if (field.eq."speed_10m".or.field.eq."mslp".or.field.eq."t2m".or.field.eq."th2m".or.field.eq."thetae".or.str_get_cols(field,0,3).eq."rain")then
			ustr = "u10"
			vstr = "v10"
		end if
		if (field@plot_windbarb .and. isfilevar(f,ustr) .and. isfilevar(f,vstr)) then
			; Regrid u and v wind components to lat-lon with ESMF_regrid function.
			; Parameters are a function of domain, mesh, and field variable.
			; Based on Bill Skamarock's scripts in /glade/p/mmm/skamaroc/Spring_exp/Test_forecasts/Test_ortho
			
			u := run_ESMF_regrid(domain,ff,f->$ustr$)
			v := run_ESMF_regrid(domain,ff,f->$vstr$)
			print("done regridding u & v wind")

			; If to_subtract is True, subtract surface wind.
			if(to_subtract) then
				u = u - run_ESMF_regrid(domain,ff,f->uzonal_surface)
				v = v - run_ESMF_regrid(domain,ff,f->umeridional_surface)
                u@long_name = "0-"+suffix+" wind shear"
			end if

			; Cosmetic changes for wind barbs
			vres = True
			vres@gsnDraw = False
			vres@gsnFrame = False
			vres@vcRefLengthF    = 0.022
			vres@vcGlyphStyle = "WindBarb"
			vres@vcPositionMode = "ArrowHead"
			vres@vcMinDistanceF = 0.023
			vres@vcRefAnnoOn = True
			vres@vcRefAnnoZone = 2
			vres@vcRefAnnoJust = "TopLeft"
			vres@vcRefAnnoParallelPosF = 0.03
			vres@vcRefAnnoString1 = "full barb = 10 kt"
			vres@vcRefAnnoString2 = "pennant = 50 kt"
            vres@vcRefAnnoFontHeightF = 0.006
			vres@vcWindBarbLineThicknessF = 1.45
			if(isatt(u,"units"))then
				if (u@units.ne."m s^{-1}")then
					print("unexpected units for wind "+u@units)
					exit
				end if
			end if
			if(.not.ismissing(str_match_ic(u@long_name,"zonal wind")))then
				; gsn_csm_vector uses u@long_name for the left title.
				; Remove the word "zonal" from left title. It is total horizontal wind, not just zonal.
				vres@gsnLeftString = str_sub_str(u@long_name, "zonal wind", "wind barb")
				vres@gsnLeftString = str_sub_str(vres@gsnLeftString, "Zonal wind", "Wind barb")
			end if
			vres@vcWindBarbScaleFactorF = 1.94384
			u@units = "kt"
			if (field.eq."cape") then
				; Uncomment to only plot wind barbs >=30 knots.
				;vres@vcMinMagnitudeF = 15.
			end if
			vres@gsnLeftStringOrthogonalPosF = -0.03
			vres@gsnLeftStringFontHeightF = 0.013
			vres@gsnRightStringOrthogonalPosF = -0.03
			vres@gsnRightStringFontHeightF = 0.013
			plot_ov := gsn_csm_vector(wks,u,v,vres)
			overlay(plot,plot_ov)
		end if   
	 

		delete(f)
		delete(height)
		delete(field_color_fill)
		draw(plot)
		print("done drawing plot object")
		delete(plot)
		frame(wks)
        timestamp = systemfunc("date '+%b %d %Y %T %Z'")
		cmd = "mogrify -trim -bordercolor white -border 5 +repage -type Palette -gravity Southwest -pointsize 9 -annotate +0+0 'created "+timestamp+"' -colors 255 "+ofile
        print(cmd)
        system(cmd)
	end do ; files loop
	delete(ff)
	print("processing success")

end

