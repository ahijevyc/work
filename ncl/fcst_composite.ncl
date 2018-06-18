;=============================================================================================
load "/glade2/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade2/work/ahijevyc/ncl/derived_fields.ncl"
load "/glade2/work/ahijevyc/ncl/run_esmf_regrid.ncl"

;=============================================================================================
; Copied from fcst-init_composite.ncl Dec 9 2015

; Average fcst from many valid times.  
; and plot a map of the variable 'fieldname'.

begin
	; Set default values if not provided on command line. For example, ncl 'mpas="mpas"' 'fieldname="precipw"' . 
	if(.not.isvar("mpas")) then
		mpas="mpas_ep"
	end if
	if(.not.isvar("fieldname")) then
		fieldname="mslp"
	end if
	prefix=""
	if(.not.isvar("year")) then
		year="2015-2014"
		prefix=year+"."
	end if
	if(.not.isvar("outdir")) then
		outdir="/glade2/work/ahijevyc/mpas_plots/"+mpas+"/"
	end if
	domain = "global"
	domain@meshdir = "/glade2/work/ahijevyc/ncl/esmf_regrid."+mpas

	; run on a composite created with nces in /glade2/work/ahijevyc/mpas_plots/season_avg.csh

	; basedir needed for init.nc
	basedir = "/glade/p/nmmm0024/"+mpas+"/"
	;basedir = "/glade/scratch/mpasrt/2014/"
	op2 = outdir + prefix +fieldname
	wks2 = gsn_open_wks("png",op2)

	iop0 = 0 
	iop1 = 120+iop0
	do iop = iop0, iop1+6, 120
		inpath = outdir+sprinti(prefix+"f%03i.nc",iop)
		t1 := addfile(inpath,"r")

		if(isfilevar(t1,fieldname))then
			field = t1->$fieldname$
		end if
		t2 = "t2m"
		if(isfilevar(t1,"t2"))then
			t2 = "t2"
		end if
		if(fieldname.eq."mse2m")then
			height = t1->height_850hPa
			height = 2.
			field = mseK(height,t1->q2,t1->$t2$)
		end if
		if(str_get_cols(fieldname,0,3).eq."mse_")then
			p_str = str_get_cols(fieldname,4,-1)
			height_str = "height_"+p_str
			height = t1->$height_str$
			p = height
			p = tofloat(p_str) ; in hPa
			t_str = "temperature_"+p_str
			rh_str = "relhum_"+p_str
			field = mseK(height,mixhum_ptrh(p,t1->$t_str$,100.*t1->$rh_str$,1),t1->$t_str$)
		end if
		if(fieldname.eq."rain24h")then
			field = get_rain(t1,inpath,-24.)
		end if
		do while(all(field.eq.0))
			iop = iop+6
			t1 := addfile(outdir+sprinti(prefix+"f%03i.nc",iop),"r")
			field = t1->$fieldname$
		end do

		lead_time = iop

		op = outdir + prefix +fieldname + sprinti(".f%03i",iop)
		wks = gsn_open_wks("png",op)

		;SET RESOURCES:
		res := get_field_res(wks,fieldname,field)
		;res := get_field_res(wks,"difference field for latent heat",field)
		res@mpMinLatF             =   -12.
		res@mpMaxLatF             =   24.
		res@mpMinLonF             =  -125. + 360.
		res@mpMaxLonF             =  -95. + 360.
		res@mpCenterLonF          = (res@mpMinLonF + res@mpMaxLonF)*0.5
		ff := addfile(basedir+str_get_cols(year,0,3)+"082500/init.nc","r")
		extrastride=1
		res = set_res_sf(res, ff, field, extrastride)
		u := run_ESMF_regrid(domain,ff,t1->u10)
		v := run_ESMF_regrid(domain,ff,t1->v10)

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
		u@units="kt"

		res@tiMainString = year+" "+mpas+" "+sprintf("%.0f",lead_time)+"h fcst"
		; this controls the size and location of the global plot
		res@vpXF            = 0.1    
		res@vpWidthF        = 0.6   
		res@vpYF            = 0.85
		res@vpHeightF       = 0.6
		plot := gsn_csm_contour_map(wks,field(0,:),res)
		plot_ov := gsn_csm_vector(wks,u,v,vres)
		overlay(plot,plot_ov)
		draw(plot)

		dlat = 1.
		f = new(round(180/dlat,3),"double")
		copy_VarAtts(field,f); if there are any units or long_name to be captured... 
		lats = new(round(180/dlat,3),"double")
		lats!0 = "latitude"
		lats@long_name = "latitude"
		lats@units = "degrees_north"
		do lat = -90., 90-dlat, dlat
			i = round((lat+90)/dlat,3)
			f(i) = avg(mask(field,onedtond(res@sfYArray.ge.lat.and.res@sfYArray.lt.lat+dlat.and.\
			       res@sfXArray.ge.res@mpMinLonF.and.res@sfXArray.lt.res@mpMaxLonF,dimsizes(field)),True))
			lats(i) = lat+dlat/2.
		end do
		lats&latitude = lats
		copy_VarCoords(lats,f)
		xyres                  	 := True                   ; plot mods desired

		xyres@xyMarkLineModes     = (/"Lines"/)  ; choose which have markers
		xyres@xyDashPatterns      = (/"Solid"/)                
		xyres@xyLineThicknesses   = (/2/) 
		xyres@xyLabelMode         = "Custom"
		xyres@tiMainString        = "zonal avg"
		xyres@tmXMajorGrid        = True
		xyres@tmXMajorGridThicknessF =0.5
		xyres@tmXMajorGridLineDashPattern = 2
		xyres2 := xyres
		xyres2@gsnFrame           = False
		xyres2@trXMinF            = res@mpMinLatF
		xyres2@trXMaxF            = res@mpMaxLatF
		xyres2@tiMainString       = year + " zonal avg"
		xyres@tmYLOn              = False
		xyres@tmYROn              = False
		xyres@trYMinF             = res@mpMinLatF
		xyres@trYMaxF             = res@mpMaxLatF
		; this controls the size and location of the zonal average plot
		bb = NhlGetBB(plot)
		xyres@vpXF             = bb(3) + 0.01
		xyres@vpWidthF         = 1. - xyres@vpXF - 0.04
		xyres@vpYF             = res@vpYF
		xyres@vpHeightF        = res@vpHeightF

		if(fieldname.eq."temperature_850hPa")then
			xyres2@trYMinF = 12.
			xyres2@trYMaxF = 22.
		end if
		if(fieldname.eq."mslp")then
			xyres2@trYMinF = 1008.
			xyres2@trYMaxF = 1015.
		end if

		; use xrange from previous forecast hour if available
		if(isvar("lineplot"))then
			xyres@trXMinF             = XMinF
			xyres@trXMaxF             = XMaxF
		end if

		lineplot := gsn_csm_xy(wks,f,lats,xyres)

		if(isvar("lineplot2"))then
			xyres2@gsLineLabelString = sprintf("%.0f h",iop)
			xyres2@gsLineColor       = "blue"
			delete(xyres2@gsnFrame)
			gsn_polyline(wks2,lineplot2,lats,f,xyres2)
		else
			xyres2@xyExplicitLabels = (/ sprintf(" %.0f h",iop)/)
			lineplot2 := gsn_csm_xy(wks2,lats,f,xyres2)
		end if
		print(f({res@mpMinLatF:res@mpMaxLatF}))

		; save xrange for next frame
		getvalues lineplot
			"trXMinF" : XMinF
			"trXMaxF" : XMaxF
		end getvalues
		print("made "+op)
	end do
	frame(wks2)
end

;=============================================================================================
