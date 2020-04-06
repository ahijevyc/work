load "/glade/work/ahijevyc/ncl/sscript.ncl"
load "/glade/work/ahijevyc/ncl/shapefile_utils.ncl"; https://www.ncl.ucar.edu/Applications/Scripts/shapefile_utils.ncl 20181101
undef("get_field_res")
function get_field_res (wks:graphic, fieldname:string, field:numeric)

;
; Based on "fieldname", set graphic and contour resources approprately.
;
; Input
;	wks:
;		graphic workstation
;	fieldname:
;		string name of field, may contain field and vertical level e.g. height_500hPa
;	field:
;		actual numeric field to plot (may be altered)
;
; Ways input variables may be changed:
;	set colormap for wks with 
;		gsn_define_colormap()
;	field: field may be converted by applying scale factor and/or offset
;	 	"units" attribute will be changed accordingly
;	field@units ; used as right title of plot
;	field@long_name = fieldname ; left title of plot
;	field@name = fieldname
; 
; Output
;	res: plotting resources for color-filled field
;		gsnDraw  = False ; default True
;		gsnFrame = False ; default True
;		gsnSpreadColorEnd
;		gsnSpreadColorStart
;		cnFillOn = True
;		cnLinesOn = False
;		cnFillMode = "RasterFill"
;		cnMinLevelValF  
;		cnMaxLevelValF  
;		cnLevelSpacingF
;       cnInfoLabelString deleted 
;
;


local hPa, long_name_guess
begin


	; Grab pressure level it it exists. Look for string "hPa"
	hPa := ""
	if (str_get_cols(fieldname,-3,-1) .eq. "hPa") then
		; Find last underscore
		i = str_index_of_substr(fieldname,"_",-1)
		; Extract characters after last underscore, up to "hPa"
		hPa = str_get_cols(fieldname,i+1,str_index_of_substr(fieldname,"hPa",-1)-1)
	end if
	if(isatt(field,"lv_ISBL0"))then
		hPa = field@lv_ISBL0/100
	end if
    ; Initialize long_name_guess to fieldname string.
    ; It may be redefined in one of the individual if-blocks.
	long_name_guess = fieldname

	;SET RESOURCES:
	res = True

	res@gsnDraw  = False ; default True
	res@gsnFrame = False ; default True
	res@gsnMaximize = False ; default False
	res@gsnSpreadColors = True ; default False
	;res@gsnPanelTop = 0.5
	field@name = fieldname

	res@cnFillOn       = True
	res@cnLinesOn      = False
	; runs faster with "RasterFill"
	res@cnFillMode = "RasterFill"

	; Reset to default so you can reuse the "res" variable for different plots. 
	res@gsnSpreadColorEnd = -1 
	res@gsnSpreadColorStart = 2

	if (fieldname.eq."AC") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -1. 
		res@cnMaxLevelValF  =  1.
		res@cnLevelSpacingF =  0.1
	end if

	if (str_get_cols(fieldname,0,3) .eq. "cape") then
		gsn_define_colormap(wks,"precip2_17lev")
		; Append greyscale to start of blue to red rainbow color map
		cmap = gsn_retrieve_colormap(wks)
		gcmap = new((/7,3/),float)
		gcmap(0:1,:) = cmap(0:1,:)
		gcmap(2:6,0) = ispan(11,7,1)/11.
		gcmap(2:6,1) = gcmap(2:6,0)
		gcmap(2:6,2) = gcmap(2:6,0)
		cmap := cmap(3:,:)
		gsn_merge_colormaps(wks, gcmap, cmap)
		res@gsnSpreadColorEnd=19
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 100,250,500,750,1000,1250,1500,1750,2000,2500,3000,3500,4000,4500,5000,5500 /)
		long_name_guess   = "CAPE, 0-6km wind shear"
		if(.not.isatt(field,"units"))then
			field@units  = "J kg~S~-1~N~"
		end if
	end if

	if (fieldname .eq. "cin") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 10,25,50,75,100,150,200,250,300,400,500/)
		long_name_guess   = "Convective inhibition (CIN)"
		if(.not.isatt(field,"units"))then
			field@units  = "J kg~S~-1~N~"
		end if
	end if

	if (fieldname .eq. "compare rain to CMORPH") then
		; taken from cmorph.ncl (probably should refer to this in that script).
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  1. * (/ 0.016, 0.025, 0.04, 0.063, 0.1, 0.16, 0.25, 0.4, 0.63, 1, 1.6, 2.5, 4, 6.3, 10, 16 /)
		if(.not.isatt(field,"units"))then
			field@units = "mm (6 h)~S~-1~N~"
		end if
		long_name_guess   = "MPAS precipitation"
	end if

	if (str_get_cols(fieldname,0,7) .eq. "dewpoint") then
		gsn_define_colormap(wks,"MPL_gist_earth")
		gsn_reverse_colormap(wks)
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -48. 
		res@cnMaxLevelValF  = 36.
		res@cnLevelSpacingF = 3.
		long_name_guess   = hPa + "hPa dew point"
        ; Assume units are Celsius if undefined.
		if(.not.isatt(field,"units"))then
			field@units  = "C"
        else
            ; Otherwise convert K to C
            if(field@units.eq."K")then
                field = field - 273.15
			    field@units  = "C"
            end if
		end if
		if (fieldname .eq. "dewpoint_surface") then
			long_name_guess   = "Surface dew point"
			res@cnLevelSelectionMode = "ExplicitLevels"
			res@cnLevels =  (/ 20,25,30,35,40,45,50,55,60,64,68,72,76 /)
            if(field@units.eq."C")then
                field = field * 9./5.
                field = field + 32.
                field@units  = "~S~o~N~F"
            end if
		end if
		if (hPa.eq."250" .or. hPa.eq."300") then
			res@cnMinLevelValF  = -63.
			res@cnMaxLevelValF  = -31.
			res@cnLevelSpacingF =   2.
		end if 
		if (hPa.eq."500") then
			res@cnMinLevelValF  = -39. 
			res@cnMaxLevelValF  =  -3.
			res@cnLevelSpacingF =   3.
		end if 
		if (hPa.eq."700") then
			res@cnMinLevelValF  = -33.
			res@cnMaxLevelValF  =  18.
			res@cnLevelSpacingF =   3.
		end if 
		if (hPa.eq."850" .or. hPa.eq."925") then
			res@cnMinLevelValF  = -27.
			res@cnMaxLevelValF  =  27.
			res@cnLevelSpacingF =   3.
		end if 
	end if

	if (fieldname .eq. "compare rain to CMORPH") then
		; taken from cmorph.ncl (probably should refer to this in that script).
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  1. * (/ 0.016, 0.025, 0.04, 0.063, 0.1, 0.16, 0.25, 0.4, 0.63, 1, 1.6, 2.5, 4, 6.3, 10, 16 /)
		if(.not.isatt(field,"units"))then
			field@units = "mm (6 h)~S~-1~N~"
		end if
		long_name_guess   = "MPAS precipitation"
	end if

	if (.not.ismissing(str_match(fieldname,"difference field for height"))) then
		gsn_define_colormap(wks,"BlueWhiteOrangeRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -50.
		res@cnMaxLevelValF  =  50.
		res@cnLevelSpacingF =   5.
		if(avg(abs(field)).gt.25)then
			res@cnMinLevelValF  = -100.
			res@cnMaxLevelValF  =  100.
			res@cnLevelSpacingF =   10.
		end if
		if(avg(abs(field)).gt.50)then
			res@cnMinLevelValF  = -200.
			res@cnMaxLevelValF  =  200.
			res@cnLevelSpacingF =   20.
		end if
		if(avg(abs(field)).lt.1)then
			res@cnMinLevelValF  = -1.
			res@cnMaxLevelValF  =  1.
			res@cnLevelSpacingF =  0.1
		end if
	end if

	if (fieldname .eq. "difference field for latent heat") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/-20,-15,-10,-7.5,-5,-2.5,0, 2.5, 5, 7.5, 10, 15, 20/)
		if(.not.isatt(field,"units"))then
			field@units  = "W m~S~-2~N~"
		end if
	end if

	if (fieldname.eq."difference field for mse") then
		gsn_define_colormap(wks,"temp_diff_18lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -1.8
		res@cnMaxLevelValF  =  1.8
		res@cnLevelSpacingF = 0.2  
		res@cnMinLevelValF  = -5. ; for Fig 9 of paper
		res@cnMaxLevelValF  =  5. ; for Fig 9 of paper
		res@cnLevelSpacingF = 0.5  
		if(.not.isatt(field,"units"))then
			field@units  = "K"
		end if
	end if

	if (fieldname.eq."difference field for mslp") then
		gsn_define_colormap(wks,"temp_diff_18lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -3.6
		res@cnMaxLevelValF  =  3.6
		res@cnLevelSpacingF = 0.4 
		field = field / 100.
		if(.not.isatt(field,"units"))then
			field@units  = "hPa"
		else if (field@units .ne. "hPa") then
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		end if
	end if

	if (fieldname .eq. "difference field for precipw") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -6.
		res@cnMaxLevelValF  =  6.
		res@cnLevelSpacingF =  1. 
		if(.not.isatt(field,"units"))then
			field@units  = "kg m~S~-2~N~"
		end if
	end if

	if (fieldname .eq. "difference field for q2") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -0.0024
		res@cnMaxLevelValF  =  0.0024
		res@cnLevelSpacingF = 0.0004 
		if(.not.isatt(field,"units"))then
			field@units  = "kg kg~S~-1~N~"
		end if
	end if

	if (fieldname .eq. "difference field for rain") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/-2,-1.5,-1,-0.75,-0.5,-0.25,0, 0.25, 0.5, 0.75, 1, 1.5, 2/)
		if(.not.isatt(field,"units"))then
			field@units  = "mm"
		else if (field@units .ne. "mm") then
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		end if
	end if

	if (fieldname .eq. "difference field for relhum_850hPa" .or. fieldname .eq. "difference field for relhum_700hPa" .or. fieldname .eq. "difference field for relhum_500hPa") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -0.3
		res@cnMaxLevelValF  =  0.3
		res@cnLevelSpacingF = 0.05 
		field@units  = "fraction 0-1"
	end if

	if (fieldname .eq. "difference field for skintemp" .or. fieldname .eq. "difference field for t2" .or. fieldname .eq. "difference field for t2m") then
		gsn_define_colormap(wks,"temp_diff_18lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -0.9
		res@cnMaxLevelValF  =  0.9
		res@cnLevelSpacingF = 0.1 
		field@units  = "K"
	end if


	if (fieldname .eq. "difference field for temperature_850hPa" .or. fieldname .eq. "difference field for temperature_700hPa") then
		gsn_define_colormap(wks,"temp_diff_18lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -3.6
		res@cnMaxLevelValF  =  3.6
		res@cnLevelSpacingF = 0.4 
		field@units  = "K"
	end if

	if (fieldname .eq. "difference field for temperature_500hPa") then
		gsn_define_colormap(wks,"temp_diff_18lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -1.8
		res@cnMaxLevelValF  =  1.8
		res@cnLevelSpacingF = 0.2 
		field@units  = "K"
	end if

	if (fieldname .eq. "difference field for terrain") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/-1000,-500,-200,-100,-50,-25,0, 25, 50, 100, 200, 500, 1000/)
	end if

	if (fieldname .eq. "difference field for u10" .or. fieldname .eq. "difference field for v10" .or. fieldname .eq. "difference field for s10") then
		gsn_define_colormap(wks,"MPL_PuOr")
		gsn_reverse_colormap(wks)
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -3.0
		res@cnMaxLevelValF  =  3.0
		res@cnLevelSpacingF = 0.5 
		field@units  = "m s~S~-1~N~"
	end if

	if (str_get_cols(fieldname,0,24) .eq. "difference field for wind") then
		gsn_define_colormap(wks,"BlueWhiteOrangeRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -20.
		res@cnMaxLevelValF  =  20.
		res@cnLevelSpacingF =   4.
		; switched from knots to m/s Jun 24, 2016
		toknots = False
		if(toknots)then ; convert m/s to knots
			if(isatt(field,"units"))then
				if(field@units.eq."m/s".or.field@units.eq."m s-1")then
					field@units  = "kt"
					; convert to knots.
					field = field * 1.94384
				end if
			else
				field@units = "kt"	
				; convert to knots.
				field = field * 1.94384
			end if
		else
			if(isatt(field,"units"))then
				if(field@units.eq."kt".or.field@units.eq."knots")then
					field@units = "m s~S~-1~N~"
					; convert to m/s
					field = field / 1.94384
				end if
			else
				field@units = "m s~S~-1~N~"
			end if
		end if
	end if

	if (str_get_cols(fieldname,0,22) .eq. "difference field for w_") then
		gsn_define_colormap(wks,"precip_diff_12lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -.03
		res@cnMaxLevelValF  =  .03
		res@cnLevelSpacingF = 0.005 
		field@units  = "m s~S~-1~N~"
	end if

	if (.not.ismissing(str_match(fieldname,"_flashrate"))) then
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 70, 100 /)
		long_name_guess   = "Lightning flash rate"
		if(.not.isatt(field,"units"))then
			field@units  = "min~S~-1~N~"
		end if
    end if

	if (fieldname .eq. "hfx") then
		gsn_define_colormap(wks,"amwg256")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@lbLabelAutoStride = False
		res@cnLevels =  (/ -80, -60, -40, -30, -20, -15, -10, -5, 0, 10, 20, 30, 50, 75, 100, 150, 300 /)
		long_name_guess   = "Upward sensible heat flux at surface"
		if(.not.isatt(field,"units"))then
			field@units  = "W m~S~-2~N~"
		end if
	end if

	if (fieldname .eq. "inundation") then
		gsn_define_colormap(wks,"StepSeq25")
        gsn_reverse_colormap(wks)
        res@gsnSpreadColorStart = 7
        res@cnLevelSelectionMode = "ExplicitLevels"
        res@lbLabelAutoStride = False
        res@cnLevels =     (/    0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.2, 1.4, 1.6, 1.8,  2,  2.5,  3,  4,  5 /)
        res@lbLabelStrings = (/ "0.1", "",  "", "", "0.5", "", "",  "",  "", "1", "",  "", "",   "", "2","2.5","3","4","5"/)
		long_name_guess   = "Inundation"
		if(.not.isatt(field,"units"))then
			field@units  = "m"
		end if
	end if

	if (fieldname .eq. "lfc" .or. fieldname .eq. "lcl") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 0,250,500,750,1000,1250,1500,2000,2500,3000,3500,4000,4500/)
		long_name_guess   = str_upper(fieldname) + " height"
		if(.not.isatt(field,"units"))then
			field@units  = "m"
		end if
	end if

	if (fieldname .eq. "lh") then
		gsn_define_colormap(wks,"MPL_BrBG")
		res@gsnSpreadColorStart=40
		res@gsnSpreadColorEnd=126
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@lbLabelAutoStride = False
		res@cnLevels =  (/ -20, -10, 0, 20, 40, 80, 160, 320, 640 /)
		long_name_guess   = "Latent heat flux at surface"
		if(.not.isatt(field,"units"))then
			field@units  = "W m~S~-2~N~"
		end if
	end if

	if (str_get_cols(fieldname,0,15).eq."lightning_threat") then
		gsn_define_colormap(wks,"prcp_1")
		res@cnFillColors = (/ 2, 3, 4, 5, 9, 8, 7, 6, 10, 11, 12, 13, 14, 15 /)
        res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels  =  (/ 0.01, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 10, 12 /)
		long_name_guess   = "Lightning threat"
		if(.not.isatt(field,"units"))then
			field@units  = "min~S~-1~N~"
		end if
    end if

	if (fieldname .eq. "mslp" .or. fieldname .eq. "msl_P1_L101_GLL0".or.fieldname.eq."PRMSL_P0_L101_GLL0") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =   999.
		res@cnMaxLevelValF  =  1018.
		res@cnLevelSpacingF =     1. 
		field@units = "Pa"
		if(max(field).ge.1200)then
			field = field / 100.
			field@units = "hPa"
		end if
		long_name_guess   = "Mean sea level pressure"
	end if

	if (fieldname .eq. "ttr_P11_L8_GLL0_acc") then
		field = -field/field@forecast_time0/3600.
	end if

	if (fieldname .eq. "olrtoa" .or. fieldname .eq. "ttr_P11_L8_GLL0_acc") then
		gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  80.
		res@cnMaxLevelValF  = 320.
		res@cnLevelSpacingF =  20. 
		long_name_guess   = "TOA outgoing LW radiation"
		if(.not.isatt(field,"units"))then
			field@units  = "W m~S~-2~N~"
		end if
	end if

	if (fieldname .eq. "precipw") then
		gsn_define_colormap(wks,"MPL_gist_earth")
		gsn_reverse_colormap(wks)
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  4.
		res@cnMaxLevelValF  = 72.
		res@cnLevelSpacingF =  4. 
		long_name_guess   = "Precipitable water"
		if(.not.isatt(field,"units"))then
			field@units  = "kg m~S~-2~N~"
		end if
	end if

	if (fieldname.eq."tp_P11_L1_GLL0_acc".or.fieldname.eq."APCP_P8_L1_GLL0_acc6h".or.fieldname.eq."ACPCP_P8_L1_GLL0_acc6h".or.fieldname.eq."PRATE_P8_L1_GLL0_avg6h") then
		gsn_define_colormap(wks,"StepSeq25")
		gsn_reverse_colormap(wks)
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@lbLabelAutoStride = False
		res@cnLevels = (/ 0.01, 0.04, 0.06, 0.08, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.2, 1.4, 1.6, 1.8,  2, 2.5,  3,  4, 5 /)
		res@lbLabelStrings = (/ "0.01", "", "", "", "0.1", "", "", "", "", "0.5", "", "",  "",  "", "1", "",  "", "",   "","2",  "","3","4","5"/)
		if(isatt(field,"units"))then
			if(field@units.eq."mm".or.field@units.eq."kg/m^2".or.field@units.eq."kg m-2")then
				field@units  = "inches"
				field = field / 25.4
			end if
			if(field@units.eq."kg m-2 s-1")then
				field@units  = "inches (6h)~S~-1~N~"
				field = field / 25.4 * 3600. * 6.
			end if
		else
			field@units = "inches"	
			field = field / 25.4
		end if
		long_name_guess = "6-h accum. precip."
		if (fieldname.eq."PRATE_P8_L1_GLL0_avg6h") then
			long_name_guess = "6-h avg. precip. rate"
		end if
		if (fieldname.eq."ACPCP_P8_L1_GLL0_acc6h") then
			long_name_guess = "6-h accum. conv. precip."
		end if
		if(isatt(field,"_FillValue"))then
			field = where(field.eq.0,field@_FillValue,field)
		end if
		res@cnConstFEnableFill = True
	end if

	if (fieldname .eq. "q2") then
		gsn_define_colormap(wks,"MPL_gist_earth")
		gsn_reverse_colormap(wks)
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 0.000
		res@cnMaxLevelValF  = 0.026
		res@cnLevelSpacingF = 0.002 
		long_name_guess = "2-m mixing ratio"
        if(.not.isatt(field,"units"))then
            field@units = "kg kg~S~-1~N~"
        end if
	end if

	if (str_get_cols(fieldname,0,3).eq."rain") then
		gsn_define_colormap(wks,"precip2_17lev")
		desc = "Precipitation"
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels :=  (/ 0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 10 /)
        ; If not set to True, some labels may be skipped due to potential overlap.
		res@lbAutoManage = True
		ipos = 4
		if (str_get_cols(fieldname,0,4).eq."rainc") then
			ipos = 5
			desc = "Parameterized rainfall"
		end if 
		if (str_get_cols(fieldname,0,5).eq."rainnc") then
			ipos = 6
			desc = "Explicit rainfall"
		end if 
		if (str_get_cols(fieldname,0,5).eq."rainmm") then
			ipos = 6
			desc = "Rainfall"
		end if 
		accum_h  = str_get_cols(fieldname,ipos,-2)
		long_name_guess  = desc + " over last " + accum_h +" h"
		if (stringtointeger(accum_h) .ge. 120) then
		    ; green at 1"
			res@cnLevels :=  (/ 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 10, 15, 20 /)
		end if
		if (stringtointeger(accum_h) .le. 3) then
			res@cnLevels :=  (/ 0.005, 0.01, 0.02, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3/)
		end if
		if(isatt(field,"units"))then
			if(str_get_cols(field@units,0,1).eq."mm")then
				field@units  = "inches"
				field = field / 25.4
			end if
		else
			field@units = "inches"	
			field = field / 25.4
		end if
        if(fieldname.eq."rainmm6h") then
		    gsn_define_colormap(wks,"prcp_1")
		    res@cnLevels :=   4. * (/ 0.016, 0.025, 0.04, 0.063, 0.1, 0.16, 0.25, 0.4, 0.63, 1, 1.6, 2.5, 4, 6.3, 10., 16. /)
			field@units = "mm"	
			field = field * 25.4
        end if
	end if

	if (str_get_cols(fieldname,0,7) .eq. "refl10cm".or.fieldname.eq."REFD") then
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 75. 
		res@cnLevelSpacingF =  5.
		long_name_guess   = str_get_cols(fieldname,9,-1) + " AGL reflectivity" 
		if (fieldname .eq. "refl10cm_1km_max") then
			long_name_guess   = "Hourly max. 1km AGL reflectivity"
			res@cnMinLevelValF = 5.
		end if
		if (fieldname .eq. "refl10cm_max") then
			long_name_guess   = "Composite reflectivity"
		end if
		field@units  = "dBZ"
	end if

	if (str_get_cols(fieldname,0,5) .eq. "relhum") then
		gsn_define_colormap(wks,"MPL_BrBG"); 128 colors in MPL_BrBG
		res@gsnSpreadColorStart=8
		res@gsnSpreadColorEnd=118
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =   0.
		res@cnMaxLevelValF  = 100.
		res@cnLevelSpacingF =  10.
		long_name_guess   = hPa + "hPa rel. humidity"
		if(.not.isatt(field,"units"))then
			field@units  = "fraction 0-1"
			if(max(field).lt.2)then
				field = field * 100.
				field@units  = "%"
			end if
		end if
	end if

	if (fieldname .eq. "rmse for 10m wind vector") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 15.
		res@cnLevelSpacingF =  1.
		field@units  = "m s~S~-1~N~"
	end if

	if (fieldname .eq. "rmse for mslp") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 12.
		res@cnLevelSpacingF =  0.5
		field = field / 100.
		field@units  = "hPa"
	end if

	if (fieldname .eq. "rmse for precipw") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 16.
		res@cnLevelSpacingF =  1.
		field@units  = "kg m~S~-2~N~"
	end if

	if (fieldname .eq. "rmse for q2") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 0.0005
		res@cnMaxLevelValF  = 0.008
		res@cnLevelSpacingF = 0.0005 
		field@units  = "kg kg~S~-1~N~"
	end if

	if (fieldname .eq. "rmse for skintemp") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.5 
		res@cnMaxLevelValF  =  7.
		res@cnLevelSpacingF =  0.5
		field@units  = "K"
	end if

	if (fieldname .eq. "rmse for t2" .or. fieldname .eq. "rmse for temperature_850hPa" .or. fieldname .eq. "rmse for temperature_700hPa" .or. fieldname .eq. "rmse for temperature_500hPa") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 15.
		res@cnLevelSpacingF =  1.
		field@units  = "K"
	end if

	if (fieldname .eq. "rmse for u10" .or. fieldname .eq. "rmse for v10") then
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  0.
		res@cnMaxLevelValF  = 12.
		res@cnLevelSpacingF =  1.
		field@units  = "m s~S~-1~N~"
	end if

	if (str_get_cols(fieldname,0,4) .eq. "shear") then
		gsn_define_colormap(wks,"wind_17lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 30.
		res@cnMaxLevelValF  = 75.
		res@cnLevelSpacingF =  5.
		layer = str_sub_str(str_get_cols(fieldname,6,-1),"_","-")
		long_name_guess   = layer + " wind shear"
		field@units   = "kt"
		; convert to knots.
		field = field * 1.94384
	end if

	if (fieldname .eq. "skintemp" .or. str_get_cols(fieldname,0,1) .eq. "t2" .or. fieldname .eq. "sst") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@gsnSpreadColorEnd=200
		res@cnLevelSelectionMode = "ManualLevels"
		; 40-87 used for the longest time
		res@cnMinLevelValF  =  -30.
		res@cnMaxLevelValF  =  115.
		res@cnLevelSpacingF =    5.
		if (str_get_cols(fieldname,0,1) .eq. "t2") then
			long_name_guess   = "2m temperature"
			field = 32 + 9./5. * (field - 273.15)
		end if
		if (fieldname .eq. "skintemp") then
			long_name_guess   = "Skin temperature"
			field = 32 + 9./5. * (field - 273.15)
		end if
		if (fieldname .eq. "sst") then
			long_name_guess   = "Sea surface temperature"
		end if
		field@units  = "~S~o~N~F"
	end if

	if (str_get_cols(fieldname,0,3).eq."snow") then
		gsn_define_colormap(wks,"precip2_17lev")
		long_name_guess = "Snow Water Equivalent"
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@lbLabelAutoStride = False
		res@cnLevels =  (/ 0.01, 0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 20, 25, 50, 75, 100 /)
		res@lbLabelStrings = (/ "0.01", "0.1", "0.2", "0.5", "1", "2", "5", "10", "15", "20", "25", "50",  "75", "100"/)
		field@units = "mm"
	end if

	if (str_get_cols(fieldname,0,4) .eq. "speed".or.fieldname.eq."ugrd" .or. fieldname.eq."UGRD_P0_L100_GLL0") then
		gsn_define_colormap(wks,"wind_17lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  =  30.
		res@cnMaxLevelValF  = 180.
		res@cnLevelSpacingF =  10.
		long_name_guess   = "Wind speed"


		if(hPa.ne."")then
			long_name_guess   = hPa + "hPa "+long_name_guess

            ; lower speed range above 850hPa and below 400hPa, or above 100hPa
            if ((hPa .lt. 850. .and. hPa .gt. 400.).or.hPa.lt.100.) then
                res@cnMinLevelValF  =  20.
                res@cnMaxLevelValF  = 100.
            end if
            ; lowest speed range at or below 850hPa
            if (hPa .ge. 850.) then
                res@cnMinLevelValF  =  15.
                res@cnMaxLevelValF  =  85.
		        res@cnLevelSpacingF =   5.
            end if
		end if
	

		if (fieldname .eq. "speedms") then
			gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
			res@cnMinLevelValF  =  2.
			res@cnMaxLevelValF  = 30.
			res@cnLevelSpacingF =  2.
			field@units   = "m s~S~-1~N~"
		else
			field@units   = "kt"
			; convert to knots.
			field = field * 1.94384
		end if
	end if

	if (fieldname.eq."s10" .or. fieldname.eq."speed_10m") then
		gsn_define_colormap(wks,"wind_17lev")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 15.
		res@cnMaxLevelValF  = 85.
		res@cnLevelSpacingF =  5.
		long_name_guess   = "10m wind speed"
        ; if-block above already converted m/s to kt when fieldname starts with "speed"
		if (field@units .ne. "kt" ) then
            print("unexpected units for speed_10m: "+field@units)
            exit
        end if
		; don't add a scale factor to convert to knots.
		; the get_speed() function or the if-block above already did.
	end if

	if (str_get_cols(fieldname,0,2) .eq. "srh") then
		; matches ncar ensemble forecasts (www.image.ucar.edu/wrfdart/ensemble)
		;res@cnFillColors = (/ (/1,1,1,1/),(/.14,.78,.24,1/),(/.39,.87,.47,1/),(/.88,.97,.59,1/),(/.64,.49,.38,1/),(/.64,.49,.46,1/),(/.78,.69,.67,1/),(/1,1,1,1/) /)
		;res@cnLevels =  (/ 50, 100, 150, 200, 250, 300, 400 /)
		gsn_define_colormap(wks,"wind_17lev")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 400, 500, 600 /)
		layer = str_sub_str(str_get_cols(fieldname,4,-1),"_","-")
		long_name_guess   = layer + " storm rel. helicity"
		if (str_get_cols(fieldname,-3,-1).eq."3km") then
			long_name_guess = long_name_guess  + ", 0-6km shear"
		end if
		if (str_get_cols(fieldname,-3,-1).eq."1km") then
			long_name_guess = long_name_guess  + ", 0-1km shear"
		end if
		field@units   = "m~S~2~N~ s~S~-2~N~"
		; don't add a scale factor to convert to knots.
		; the get_shear() function converts to knots.
	end if

	if (str_get_cols(fieldname,0,10) .eq. "temperature".or.fieldname.eq."TMP_P0_L100_GLL0".or.fieldname.eq."t_P1_L100_GLL0") then
		gsn_define_colormap(wks,"cmp_haxby")
		res@cnLevelSelectionMode = "ManualLevels"
		if (hPa.eq."200") then
			res@cnMinLevelValF  = -64.
			res@cnMaxLevelValF  = -42.
			res@cnLevelSpacingF =   2.
		end if 
		if (hPa.eq."250" .or. hPa.eq."300") then
			res@cnMinLevelValF  = -63.
			res@cnMaxLevelValF  = -31.
			res@cnLevelSpacingF =   2.
		end if 
		if (hPa.eq."500") then
			res@cnMinLevelValF  = -34.
			res@cnMaxLevelValF  =  -2.
			res@cnLevelSpacingF =   2.
		end if 
		if (hPa.eq."700") then
			res@cnMinLevelValF  = -28.
			res@cnMaxLevelValF  =  18.
			res@cnLevelSpacingF =   2.
		end if 
		if (hPa.eq."850") then
			res@cnMinLevelValF  = -24.
			res@cnMaxLevelValF  =  27.
			res@cnLevelSpacingF =   3.
		end if 
		if (hPa.eq."925") then
			res@cnMinLevelValF  = -21.
			res@cnMaxLevelValF  =  33.
			res@cnLevelSpacingF =   3.
		end if 
		long_name_guess   = hPa + "hPa temperature"
		field@units  = "C"
		field = field - 273.15
	end if

	if (fieldname .eq. "th2m") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@cnLevelSelectionMode = "ManualLevels"
		res@gsnSpreadColorEnd=200
		res@cnMinLevelValF  = 255.
		res@cnMaxLevelValF  = 327.
		res@cnLevelSpacingF =   3.
		long_name_guess   = "2m potential temperature"
		field@units  = "K"
	end if

	if (fieldname.eq."theta_pv")then
		gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 278.
		res@cnMaxLevelValF  = 382.
		res@cnLevelSpacingF =   4.
		res@nSmoothPasses = 3
		long_name_guess = "Pot. temperature on 2 PVU surface"
		field@units = "K"
	end if

	if (fieldname .eq. "thetae") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@cnLevelSelectionMode = "ManualLevels"
		res@gsnSpreadColorEnd=220
		res@cnMinLevelValF  = 282.
		res@cnMaxLevelValF  = 370.
		res@cnLevelSpacingF =   4.
		field@long_name = "2m equiv. potential temp."
		field@units  = "K"
	end if

	if (str_get_cols(fieldname,0,4) .eq. "thick") then
		gsn_define_colormap(wks,"nice_gfdl")
		res@cnLevelSelectionMode = "ManualLevels"
		res@gsnSpreadColorEnd=220
		res@cnMinLevelValF  = 480.
		res@cnMaxLevelValF  = 588.
		res@cnLevelSpacingF =   6.
		if(isatt(field,"units").and.field@units .ne. "m")then 
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		field = field / 10.
		field@units  = "dm"
	end if

	if (fieldname.eq."u10") then
		gsn_define_colormap(wks,"BlueWhiteOrangeRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -18. 
		res@cnMaxLevelValF  =  24. 
		res@cnLevelSpacingF =   3.
		long_name_guess   = "10-m zonal wind"
		if(.not.isatt(field,"units"))then
			field@units  = "kt"
		else if (field@units .ne. "m s^{-1}") 
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		end if	
		field = field * 1.94384
	end if

	if (fieldname.eq."v10") then
		gsn_define_colormap(wks,"BlueWhiteOrangeRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -16. 
		res@cnMaxLevelValF  =  16. 
		res@cnLevelSpacingF =   2.
		long_name_guess   = "10-m meridional wind"
		if(.not.isatt(field,"units"))then
			field@units  = "kt"
		else if (field@units .ne. "m s^{-1}") 
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		end if
		field = field * 1.94384
	end if

	if (str_get_cols(fieldname,0,15) .eq. "updraft_helicity") then
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ExplicitLevels"
		res@cnLevels =  (/ 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 400 /)
		res@nSmoothPasses = 3
		long_name_guess   = "Hourly max. updraft helicity"
		if (fieldname .eq."updraft_helicity_max24h") then
            ; This is not long_name_guess. We need to override the default long_name,
            ; Max UH since last output.
			field@long_name = "Max. updraft helicity over last 24h"
		end if
		field@units  = "m~S~2~N~ s~S~-2~N~"
	end if

	if (str_get_cols(fieldname,0,8).eq."vorticity" .or. str_get_cols(fieldname,0,9).eq."divergence") then
		gsn_define_colormap(wks,"BlueWhiteOrangeRed")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = -36. 
		res@cnMaxLevelValF  =  36. 
		res@cnLevelSpacingF =   8.
		res@nSmoothPasses = 25
        res@cnInfoLabelOrthogonalPosF = 0.06
		if(hPa.eq.850)then
			res@cnMinLevelValF  = -55. 
			res@cnMaxLevelValF  =  55. 
			res@cnLevelSpacingF =  10.
		end if
		i = str_index_of_substr(fieldname,"_",-1)
		long_name_guess   = hPa + "hPa "+str_get_cols(fieldname,0,i-1)
		field@units  = "10~S~-5~N~s~S~-1~N~"
		field = field * 1e5
	end if

	if (fieldname .eq. "wind_speed_level1_max") then
		gsn_define_colormap(wks,"prcp_1")
		res@cnLevelSelectionMode = "ManualLevels"
		res@cnMinLevelValF  = 30.
		res@cnMaxLevelValF  = 85.
		res@cnLevelSpacingF =  5.
		field@long_name = "Max. wind on lowest level over last hour"
		field = field * 1.94384
		field@units   = "kt"
	end if

	if (str_get_cols(fieldname,0,1) .eq. "w_") then
		if (hPa .ne. "") then
            gsn_define_colormap(wks,"CBR_coldhot")
            res@cnLevelSelectionMode = "ExplicitLevels"
            res@cnLevels =  (/ -0.5, -0.2, -0.1, -0.05, -0.02, 0, .02, .05, .1, .2, .5 /)
		    res@nSmoothPasses = 10
            long_name_guess   = hPa + "hPa vertical velocity"
		else
            gsn_define_colormap(wks,"prcp_1")
            res@cnLevelSelectionMode = "ExplicitLevels"
            ;res@cnLevels =  (/4,6,8,10,12,14,16,18,20,24,28,32,36,40,44/) 
            ; Lou Wicker requested > 10m/s
            res@cnLevels =  (/10,12,14,16,18,20,24,28,32,36,40,44/) 
            field@long_name   = "Max. updraft speed over last hour"
		end if
		field@units  = "m s~S~-1~N~"
	end if

    ; Only define the field@long_name attribute if it hasn't been defined already.
    ; Now that MPAS produces long_name attributes, why not use them?
	if(.not.isatt(field,"long_name"))then
        ; long_name_guess was initialized as the fieldname string.
        ; It may have been redefined in one of the individual if-blocks.
		field@long_name = long_name_guess
	end if
	if(strlen(field@long_name).gt.50)then
		res@gsnStringFontHeightF = 0.016
	end if

	; if units string has parts enclosed in ^{ } , then change to superscripts
	if(isatt(field,"units"))then
		field@units = sscript(field@units)
	end if
    ; Put units below color table.
	res@lbTitleString = field@units
	res@lbTitlePosition = "Bottom"
	res@lbTitleFontHeightF = 0.01

	return(res)
end

undef("get_res_cn")
function get_res_cn (domain:string, infieldname:string, field:numeric)
;
; Return line contour resources based on "fieldname".
;
; Input
;	domain:
;		string name of domain (e.g. "global", "us")
;	infieldname:
;		string name of field, may contain field and vertical level e.g. height_500hPa
;	field:
;		actual numeric field to plot (may be altered)
;
; Changes to Input
;	field: field may be converted by applying scale factor and/or offset
;	 	"units" attribute will be changed accordingly
;	field@units ; used as right title of plot
;	field@long_name = fieldname ; left title of plot
;	field@name = fieldname
; 
; Output
;	res: plotting resources for color-filled field
;		gsnDraw  = False ; default True
;		gsnFrame = False ; default True
;		cnFillOn = False
;		cnLinesOn = True
; 		cnLineThicknessF
; 		cnLineLabelFontHeightF
;		cnLineLabelPlacementMode = "Constant" ; "Constant" contour line doesn't go thru label.
;		cnLineDashSegLenF
;		cnLineLabelInterval = 2
;		cnMinLevelValF  
;		cnMaxLevelValF  
;		cnLevelSpacingF 
;		nSmoothPasses
;


local fieldname
begin
	fieldname = infieldname
	field@name = fieldname
	; Allow for height from GFS GRIB-style files?
	; convert from HGT_blah to height_800hPa
	if(isatt(field,"lv_ISBL0"))then
		fieldname = "height_"+sprintf("%.0f",field@lv_ISBL0/100)+"hPa"
	end if
	res = True
	res@gsnDraw   = False
	res@gsnFrame  = False
	res@cnFillOn  = False
	res@cnInfoLabelString = fieldname+" contours from $CMN$ to $CMX$ by $CIU$"
	; Zone 2 is right below plot window
	res@cnInfoLabelZone = 2 ; default 3 (Zone 3 is right below color bar)
	res@cnLevelSelectionMode = "ManualLevels"
	res@cnLinesOn = True
	res@cnLineThicknessF = 3.5 ; Important to assign float (if you assign integer you can't assign a float later)
	res@cnLineLabelFontHeightF = 0.007
	res@cnLineLabelPlacementMode = "Constant" ; "Constant" contour line doesn't go thru label.
	res@cnLineDashSegLenF = 0.1
	res@cnLineLabelInterval = 2
	res@nSmoothPasses = 10
	if (domain .eq. "conus") then
		res@cnLineDashSegLenF = 0.06
		res@gsnLeftStringOrthogonalPosF = -0.08 ; Don't overwrite the filled contour label 
		res@gsnRightStringOrthogonalPosF = -0.08
	end if
	if (domain.eq."west".or.domain.eq."east".or.domain.eq."central") then
		print("moving Left and Right String ")
		res@gsnLeftStringOrthogonalPosF = -0.0 ; set to zero or it drifts away from plot boundary
		res@gsnRightStringOrthogonalPosF = -0.0
		res@gsnLeftStringFontHeightF = 0.01
		res@gsnRightStringFontHeightF = 0.01
	end if
	if (str_get_cols(fieldname,0,6).eq."height_") then
		if (fieldname.eq."height_500hPa".or.fieldname .eq. "height_700hPa" .or. fieldname .eq. "height_850hPa" .or. fieldname .eq. "height_925hPa") then
			res@cnMinLevelValF  =  450.
			res@cnMaxLevelValF  = 6030.
			res@cnLevelSpacingF =   30.
		end if
		if (fieldname .eq. "height_300hPa".or.fieldname .eq. "height_200hPa".or.fieldname.eq."height_250hPa") then
			res@cnMinLevelValF  =  6000.
			res@cnMaxLevelValF  = 15000.
			res@cnLevelSpacingF =    60.
		end if
		if(isatt(field,"long_name"))then
			if(str_get_cols(field@long_name,0,15) .eq. "Geometric height")then
				print("I don't like this, but plotting geometric height instead of geopotential")
			end if
		else
			; Default value (if there is no "long_name" attribute).
			field@long_name = "Geopotential height"
		end if
		field@units = "m"
	end if 

	if (str_get_cols(fieldname,0,4).eq."thick") then
		res@cnMinLevelValF  = 480.
		res@cnMaxLevelValF  = 588.
		res@cnLevelSpacingF =   6.
		res@cnMonoLineColor = False
		; Blue below 540dm; black for 540dm; red above 540 dm. (rain/snow line)
		res@cnLineColors = (/ "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "blue", "black", "red",  "red", "red", "red", "red", "red", "red" /)
		if(isatt(field,"units").and.field@units .ne. "m")then 
			print("unexpected units for "+fieldname+" "+field@units)
			exit
		end if
		field = field / 10.
		field@units  = "dm"
		; account for MSLP overlay
		field@long_name = field@long_name + ", MSLP (dashed)"
		field@units = field@units + ", hPa"
	end if 


	if (fieldname .eq. "cloud_top_height" ) then
		res@cnMinLevelValF  = 0.001
		res@cnMaxLevelValF  = 20000.
		res@cnLevelSpacingF =  5000.
	end if

	if (fieldname .eq. "mslp"               .or. \
        fieldname .eq. "msl_P1_L101_GLL0"   .or. \
        fieldname .eq. "PRMSL_P0_L101_GLL0" .or. \
        fieldname .eq. "MSLET_P0_L101_GLL0" .or. \
        fieldname .eq. "MSL_GDS0_SFC" ) then
		res@cnMinLevelValF  = 900.
		res@cnMaxLevelValF  = 1060.
		res@cnLevelSpacingF =  4.
		field@units = "Pa"
		if(max(field).ge.1200)then
			field = field / 100.
			field@units = "hPa"
		end if
		field@long_name = "Mean sea level pressure"
		if(fieldname.eq."MSLET_P0_L101_GLL0")then ; I like long_name in GFS the way it is (MSLP (ETA model reduction))
			field@long_name = "MSLP (ETA model reduction)"
		end if
	end if
	if (domain .eq. "global") then
		res@cnLineLabelFontHeightF = 0.0056
		res@cnLineThicknessF = 2.0 
		res@cnLevelSpacingF = 2. * res@cnLevelSpacingF
		; Deal with explicit line colors if you double the level spacing.
		if(isatt(res, "cnMonoLineColor"))then
			if (.not. res@cnMonoLineColor)then 
				res@cnLineColors := res@cnLineColors(::2)
			end if
		end if
	end if


	return(res)
end


undef("set_res_mp")
function set_res_mp (res:logical, domain:string)
; Set mp (map) resources for plot based on domain.
; This includes...
;		res@mpMinLatF
;		res@mpMaxLatF
;		res@mpMinLonF
;		res@mpMaxLonF
;		res@mpProjection
;		res@mpCenterLonF
;		res@mpCenterLatF

begin

	;SET RESOURCES:

	res@mpProjection        = "CylindricalEquidistant"
	res@mpDataBaseVersion   = "Dynamic" 
	res@mpOutlineBoundarySets="GeophysicalAndUSStates"
	res@mpUSStateLineThicknessF=1.25
	res@mpGeophysicalLineThicknessF=1.75
	res@mpGeophysicalLineColor = "gray40"
	res@mpPerimOn = True
	res@mpLimitMode = "LatLon"
	res@mpGridSpacingF = 30.

	if (domain.eq."nh")then
		delete(res@mpProjection)
		res@gsnPolar="NH"
		res@mpMinLatF=20.
		res@mpCenterLonF=-97.5
	end if
	if (domain .eq. "central") then
		res@mpMinLatF=30.
		res@mpMaxLatF=45.
		res@mpMinLonF=-109.
		res@mpMaxLonF=-89.
		res@mpProjection="Orthographic"
		res@mpCenterLonF=-97.5
		res@mpCenterLatF=38.
		res@mpOutlineBoundarySets="AllBoundaries"
		res@mpCountyLineColor="gray70"
		res@mpCountyLineThicknessF=0.5
		res@tiMainOffsetYF = 0.02
	end if
	if (domain.eq."conus".or.domain.eq."hwt2017".or.domain.eq."mpas50_3") then
		res@mpMinLatF=25.
		res@mpMaxLatF=51.
		res@mpMinLonF=-122.
		res@mpMaxLonF=-72.
		res@mpProjection="Orthographic"
		res@mpCenterLonF=-97.5
		res@mpCenterLatF=38.
	end if
	if (domain .eq. "io") then
		res@mpMinLatF=19.
		res@mpMaxLatF=34.
		res@mpMinLonF=46.
		res@mpMaxLonF=74.
		res@mpProjection="CylindricalEquidistant"
	    res@mpGeophysicalLineThicknessF=3.5
		res@mpGridSpacingF = 1.
	end if
	if (domain .eq. "na") then
		res@mpMinLatF=15.
		res@mpMaxLatF=65.
		res@mpMinLonF=-145.
		res@mpMaxLonF= -55.
		res@mpCenterLonF = -100.
		res@mpCenterLatF =   35.
	end if
	if (domain .eq. "east") then
		res@mpMinLatF=25.
		res@mpMaxLatF=50.
		res@mpMinLonF=-105.
		res@mpMaxLonF=-72.
		res@mpProjection="Orthographic"
		res@mpCenterLonF=-97.5
		res@mpCenterLatF=38.
	end if
	if (domain .eq. "west") then
		res@mpMinLatF=25.
		res@mpMaxLatF=50.
		res@mpMinLonF=-122.
		res@mpMaxLonF=-90.
		res@mpProjection="Orthographic"
		res@mpCenterLonF=-97.5
		res@mpCenterLatF=38.
	end if
	if (domain .eq. "global") then
		res@mpMinLatF=-90.
		res@mpMaxLatF= 90.
		res@mpMinLonF=-180.
		res@mpMaxLonF=180.
		res@mpProjection="CylindricalEquidistant"
		res@mpOutlineBoundarySets="Geophysical"
		res@mpCenterLonF=0.
		res@mpCenterLatF=0.
	end if
	if (domain .eq. "tropics") then
		res@mpMinLatF=-60.
		res@mpMaxLatF= 60.
		res@mpMinLonF=-180.
		res@mpMaxLonF=180.
		res@mpProjection="CylindricalEquidistant"
		res@mpOutlineBoundarySets="Geophysical"
		res@mpCenterLonF=0.
		res@mpCenterLatF=0.
	end if
	if (domain .eq. "al") then
		res@mpMinLatF=   5.
		res@mpMaxLatF=  50.
		res@mpMinLonF=-100.
		res@mpMaxLonF= -20.
		res@mpCenterLonF = -60.
		res@mpCenterLatF =    0. ; Important to be zero, so parallels are straight
		res@mpProjection="CylindricalEquidistant"
		res@mpOutlineBoundarySets="Geophysical"
		res@mpGeophysicalLineThicknessF=2.25
	end if
	if (domain .eq. "ep") then
		res@mpMinLatF=   5.
		res@mpMaxLatF=  45.
		res@mpMinLonF=-180.
		res@mpMaxLonF= -90.
		res@mpCenterLonF = -135.
		res@mpCenterLatF =    0. ; Important to be zero, so parallels are straight
		res@mpProjection="CylindricalEquidistant"
		res@mpOutlineBoundarySets="Geophysical"
		res@mpGeophysicalLineThicknessF=2.25
	end if
	if (domain .eq. "wp") then
		res@mpMinLatF=   5.
		res@mpMaxLatF=  55.
		res@mpMinLonF=  90.
		res@mpMaxLonF= 180.
		res@mpCenterLonF = 135.
		res@mpCenterLatF =    0. ; Important to be zero, so parallels are straight
		res@mpProjection="CylindricalEquidistant"
		res@mpOutlineBoundarySets="Geophysical"
		res@mpGeophysicalLineThicknessF=2.25
		res@mpGridSpacingF = 10.
	end if
	if (domain.eq."IKE_zoom-1".or.domain.eq."CHARIKE_zoom-1")then
		res@mpMinLatF=  19.
		res@mpMaxLatF=  46.
		res@mpMinLonF= -99.
		res@mpMaxLonF= -60.
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."IKE_zoom0")then
		res@mpMinLatF=  21.
		res@mpMaxLatF=  31.
		res@mpMinLonF= -99.
		res@mpMaxLonF= -85.
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."IKE_zoom1".or.domain.eq."CHARIKE_zoom1")then
		res@mpMinLatF=  25.
		res@mpMaxLatF=  31.
		res@mpMinLonF= -99.
		res@mpMaxLonF= -87.
		res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."IKE_zoom2")then
		res@mpMinLatF=  27.5
		res@mpMaxLatF=  30.5
		res@mpMinLonF= -97.5
		res@mpMaxLonF= -91.
		;res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 2
	end if
	if (domain.eq."IKE_zoom3")then
		res@mpMinLatF=  28.65
		res@mpMaxLatF=  28.9
		res@mpMinLonF= -96.1
		res@mpMaxLonF= -95.8
		res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 2
	end if
	if (domain.eq."IKE_zoom4")then
		res@gsnStringFontHeightF = 0.015
		res@mpGeophysicalLineThicknessF = 2
		res@mpMinLatF=  29.87
		res@mpMaxLatF=  29.88
		res@mpMinLonF= -93.93
		res@mpMaxLonF= -93.92
		res@mpMinLonF             = -97.488 ; problem near Hill (white point)
		res@mpMaxLonF             = -97.478
		res@mpMinLatF             = 27.857
		res@mpMaxLatF             = 27.865
		res@mpMinLonF             = -95.04 ; 10m obs/model difference in perfect control
		res@mpMaxLonF             = -95.00
		res@mpMinLatF             = 29.595
		res@mpMaxLatF             = 29.630
		;res@mpMinLonF             = -91.220 ; -6m node with missing zeta_max 401-ILA-03-060
		;res@mpMaxLonF             = -91.212
		;res@mpMinLatF             = 29.69
		;res@mpMaxLatF             = 29.698
		;res@mpMinLonF             = -91.239 ; zoomed out -6m node with missing zeta_max
		;res@mpMaxLonF             = -91.192
		;res@mpMinLatF             = 29.674
		;res@mpMaxLatF             = 29.712

		;res@mpMinLatF=  29.446 ; dry node >29 m below MSL
		;res@mpMaxLatF=  29.462
		;res@mpMinLonF= -89.64
		;res@mpMaxLonF= -89.625

		res@mpMinLatF=  28.76 ; small river in obs, but dry, missing value and no river in NOS grid.
		res@mpMaxLatF=  28.81
		res@mpMinLonF= -96.02
		res@mpMaxLonF= -95.97
		res@mpDataBaseVersion   = "HighRes" 
	end if
	if (domain.eq."CHARLEY_zoom0")then
		res@mpMinLatF=  19.
		res@mpMaxLatF=  46.
		res@mpMinLonF= -89.
		res@mpMaxLonF= -60.
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."CHARLEY_zoom1")then
		res@mpMinLatF=  24.25
		res@mpMaxLatF=  30.
		res@mpMinLonF= -86.
		res@mpMaxLonF= -78.
		res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."CHARLEY_zoom2")then
		res@mpMinLatF=  25.5
		res@mpMaxLatF=  27.
		res@mpMinLonF= -83.
		res@mpMaxLonF= -80.5
		res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (domain.eq."CHARLEY_zoom3")then
		res@mpMinLatF=  26.2
		res@mpMaxLatF=  26.6
		res@mpMinLonF= -82.3
		res@mpMaxLonF= -81.8
		res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 1
	end if
	if (str_upper(domain).eq."DENNIS")then ; case-insensitive for matching bdecks
		res@mpMinLatF=  21.
		res@mpMaxLatF=  37.
		res@mpMinLonF= -95.
		res@mpMaxLonF= -78.
		res@mpGeophysicalLineThicknessF = 3
		res@mpGridSpacingF = 2.
		res@mpGridLineThicknessF = 2.
	end if
	if (domain.eq."HARVEY_zoom1")then
		res@mpMinLatF=  24.75
		res@mpMaxLatF=  30.5
		res@mpMinLonF= -98.
		res@mpMaxLonF= -92.25
	end if
	if (domain.eq."HARVEY_zoom2")then
		res@mpMinLatF=  26.5
		res@mpMaxLatF=  29.5
		res@mpMinLonF= -98.
		res@mpMaxLonF= -94.
	end if
	if (domain.eq."IRMA_zoom0")then
        ; FloridaSW
        res@mpDataBaseVersion = "HighRes"
		res@mpMinLatF=  23.
		res@mpMaxLatF=  29.
		res@mpMinLonF= -84.
		res@mpMaxLonF= -79.
	end if
	if (domain.eq."IRMA_zoom1")then
		res@mpMinLatF=  24.
		res@mpMaxLatF=  35.
		res@mpMinLonF= -88.0
		res@mpMaxLonF= -77.0
	end if
	if (domain.eq."IRMA_zoom2")then
        ; FloridaSW - tweaked north to Naples, FL
        res@mpDataBaseVersion = "HighRes"
		res@mpMinLatF=  24.5
		res@mpMaxLatF=  26.2
		res@mpMinLonF= -82.3
		res@mpMaxLonF= -80.0
	end if
	if (domain.eq."IRMA_zoom3")then
        ; FloridaNE - tweaked south to Fernandina Beach, FL
		res@mpMinLatF=  30.6
		res@mpMaxLatF=  32.75
		res@mpMinLonF= -82.
		res@mpMaxLonF= -79.
		res@mpOutlineBoundarySets = "USStates"
	end if
	if (domain.eq."IRMA_zoom4")then
        ; FloridaSW
        res@mpDataBaseVersion = "HighRes"
		res@mpMinLatF=  24.5
		res@mpMaxLatF=  26.1
		res@mpMinLonF= -82.3
		res@mpMaxLonF= -80.0
	end if
	if (domain.eq."IRMA_zoom5")then
        ; Tampa
        res@mpDataBaseVersion = "HighRes"
		res@mpMinLatF=  26.5
		res@mpMaxLatF=  30.2
		res@mpMinLonF= -85.6
		res@mpMaxLonF= -81.7
		res@mpOutlineBoundarySets="AllBoundaries"
		res@mpCountyLineColor="gray70"
		res@mpCountyLineThicknessF=0.5
	end if
	if (domain.eq."IRMA_zoom6")then
        ; FloridaNE - zoomed in
		res@mpMinLatF=  31.
		res@mpMaxLatF=  32.75
		res@mpMinLonF= -82.
		res@mpMaxLonF= -79.
		res@mpOutlineBoundarySets = "USStates"
	end if
	if (domain.eq."IRMA_zoom7")then
        ; Tampa Bay through Cape Romano, FL
        res@mpDataBaseVersion = "HighRes"
		res@mpMinLatF=  25.5
		res@mpMaxLatF=  28.
		res@mpMinLonF= -83.5
		res@mpMaxLonF= -81.
	end if
	if (domain.eq."Lionrock0")then
		res@mpMinLatF=  10.
		res@mpMaxLatF=  45.
		res@mpMinLonF= 125.
		res@mpMaxLonF= 160.
		res@mpGridSpacingF = 10.
		res@mpGeophysicalLineThicknessF = 2.5
	end if
	if (domain.eq."Lionrock")then
		res@mpMinLatF=  19.
		res@mpMaxLatF=  41.
		res@mpMinLonF= 129.
		res@mpMaxLonF= 151.
		res@mpGridAndLimbOn = True
		res@mpGridLineDashPattern = "Dot"
		res@mpGridLineThicknessF = 2.
		res@mpGridSpacingF = 5.
		res@gsnMajorLatSpacing = res@mpGridSpacingF
		res@gsnMajorLonSpacing = res@mpGridSpacingF
		res@gsnMinorLatSpacing = 1
		res@gsnMinorLonSpacing = 1
		res@mpDataBaseVersion   = "HighRes" 
	end if
	if (domain.eq."Lionrock2")then
		res@mpMinLatF=  18.
		res@mpMaxLatF=  34.
		res@mpMinLonF= 127.
		res@mpMaxLonF= 143.
		res@mpGridSpacingF = 2.
		res@mpGridAndLimbOn = True
		res@mpGridLineDashPattern = "Dot"
	end if
	if (domain.eq."Matthew")then
		res@mpMinLatF=   9.
		res@mpMaxLatF=  24.
		res@mpMinLonF= -77.
		res@mpMaxLonF= -62.
		res@mpGridAndLimbOn = True
		res@mpGridLineDashPattern = "Dot"
		res@mpGridLineThicknessF = 3.
		res@mpGridSpacingF = 5.
		res@gsnMajorLatSpacing = res@mpGridSpacingF
		res@gsnMajorLonSpacing = res@mpGridSpacingF
		res@gsnMinorLatSpacing = 1
		res@gsnMinorLonSpacing = 1
		res@mpDataBaseVersion   = "HighRes" 
	end if
	if (domain.eq."MATTHEW_zoom1")then
		res@mpMinLatF=  30.
		res@mpMaxLatF=  33.
		res@mpMinLonF= -83.
		res@mpMaxLonF= -79.
		res@mpGeophysicalLineThicknessF = 2
		res@mpDataBaseVersion   = "HighRes" 
	end if
	if (domain.eq."MATTHEW_zoom2")then
		res@mpMinLatF=  31.25
		res@mpMaxLatF=  32.75
		res@mpMinLonF= -82.25
		res@mpMaxLonF= -80.75
		res@mpGeophysicalLineThicknessF = 2
		res@mpDataBaseVersion   = "HighRes" 
	end if
	if (domain.eq."Joaquin0")then
		res@mpMinLatF=  -3.
		res@mpMaxLatF=  55.
		res@mpMinLonF= -141.
		res@mpMaxLonF= -9.
		res@mpGeophysicalLineThicknessF = 2
	end if
	if (str_upper(domain).eq."JOAQUIN")then ; case-insensitive for matching bdecks
		res@mpMinLatF=  18.
		res@mpMaxLatF=  32.
		res@mpMinLonF= -80.
		res@mpMaxLonF= -66.
        ; Can't use "HighRes" in v6.4.0 right now.
		;res@mpDataBaseVersion   = "HighRes" 
		res@mpGeophysicalLineThicknessF = 3
		res@mpGridSpacingF = 2.
		res@mpGridLineThicknessF = 2.
	end if
	if (domain.eq."Joaquin2")then
		res@mpMinLatF=  12.
		res@mpMaxLatF=  43.
		res@mpMinLonF= -97.
		res@mpMaxLonF= -56.
		res@mpGeophysicalLineThicknessF = 2
	end if
    if (domain.eq."Hartford")then
		res@mpMinLatF=39.
		res@mpMaxLatF=44.5
		res@mpMinLonF=-74.5
		res@mpMaxLonF=-69.
		res@mpOutlineBoundarySets="AllBoundaries"
    end if
	if (domain.eq."RELAMPAGO")then
		res@mpMinLatF=  -40.
		res@mpMaxLatF=  -10.
		res@mpMinLonF= -75.
		res@mpMaxLonF= -45.
		res@mpGeophysicalLineThicknessF = 4
	end if
	if (domain.eq."Taiwan")then
		res@mpMinLatF=  18.0
		res@mpMaxLatF=  29.0
		res@mpMinLonF= 113.5
		res@mpMaxLonF= 128.5
		res@mpDataSetName = "Earth..4"
		res@mpDataBaseVersion = "MediumRes"
        res@mpOutlineOn = True
        res@mpOutlineSpecifiers = (/"China:states"/)
        res@mpProvincialLineColor = "gray60"
	end if
	if (domain.eq."Taiwan_zoom")then
		res@mpMinLatF=  21.5
		res@mpMaxLatF=  26.5
		res@mpMinLonF= 119.
		res@mpMaxLonF= 125.
		res@mpDataSetName = "Earth..4"
		res@mpDataBaseVersion = "MediumRes"
	end if

	if(.not.isatt(res,"mpMinLatF"))then
		print("set_res_mp: unknown domain: "+domain)
		exit
	end if

    if(isatt(res,"mpDataBaseVersion").and.res@mpDataBaseVersion.eq. "HighRes")
        print("In get_field_res: mpDataBaseVersion = HighRes")
        print("for some newer versions of ncl, this is not configured properly")
        print("and you get fatal:MapRGDHDrawMapList: MDRGSF/MDRGOF - ERROR OPENING RANGS/GSHHS CAT FILE")
        print(get_ncl_version())
    end if

	return(res)
end

undef("get_iregion")
function get_iregion (f:file, region:string, res)
local b, c, skip_check, slope, sname, s, segments, geometry, segsDims, geomDims, geom_segIndex, \
 geom_numSegs, segs_xyzIndex, segs_numPnts, numFeatures, lat1d, lon1d, \
 startSegment, numSegments, seg, startPT, endPT


begin
    if (region.eq."")then
        return(.not.ismissing(f->x))
    end if
    if (max(f->x).lt.6.3 .and. min(f->x).gt.-3.2 .and. max(f->y).lt.1.6 .and. min(f->y).gt.-1.6)then
        print("get_field_res.ncl:get_iregion: This looks like radians. exiting")
        printMinMax(f->x,0)
        printMinMax(f->y,0)
        exit
    end if
    slope = 1.5
    b = 94.0
    printMinMax(f->x,0)
    printMinMax(f->y,0)
    if (region.eq."FloridaSW")then
        okay = slope * f->x + f->y + b .lt. 0
        okay = okay .and. f->y .gt. 24
        return(okay)
    end if
    if (region.eq."FloridaNE")then
        okay = slope * f->x + f->y + b .ge. 0
        okay = okay .and. f->y .gt. 24
        return(okay)
    end if
    
    ; Below here, assume a state_county is requested

    ; Turn on county lines - TODO not working yet
    res@mpOutlineBoundarySets="AllBoundaries"
    res@mpCountyLineColor="gray70"
    res@mpCountyLineThicknessF=0.5

    junk := str_split(region, "_")
    if(dimsizes(junk).ne.2)then
        print("expected state_county, got "+region)
        exit
    end if
    cache = "/glade/work/ahijevyc/ADCIRC/regions/"+region+".nc"
    if(fileexists(cache))then
        print("reading "+ cache)
        c = addfile(cache,"r")
        ; can't store logical variable; store as byte. Return logical from this function
        return(c->okay .eq. 1b)
    end if
    mystate  = junk(0)
    mycounty = junk(1)
    okay = new(dimsizes(f->x),byte); all will be missing -127b
    nlatlon = dimsizes(f->y)
    lat1d = f->y
    lon1d = f->x
    ; tried to use cb_2013_us_county_500k but it didn't clearly associate county with a state
    ; sname = "/glade/work/ahijevyc/share/cb_2013_us_county_500k/cb_2013_us_county_500k.shp"

    ; https://gadm.org/download_country_v3.html
    ; downloaded Nov 1 2018 https://biogeo.ucdavis.edu/data/gadm3.6/shp/gadm36_USA_shp.zip 
    sname = "/glade/work/ahijevyc/share/gadm36_USA_shp/gadm36_USA_2.shp"

    print_shapefile_info(sname)
    ;---Open the shapefile
    s = addfile(sname,"r")
    ; Get the approximate index values that contain the area of interest.
    ;
    ; This will make our gc_inout loop below go faster, because we're
    ; not checking every single lat/lon point to see if it's within
    ; the area of interest.
    ;
    ii_latlon = ind(lat1d.ge.res@mpMinLatF.and.lat1d.le.res@mpMaxLatF.and.\
                    lon1d.ge.res@mpMinLonF.and.lon1d.le.res@mpMaxLonF)
    nii_latlon = dimsizes(ii_latlon)

    ;---Read data off the shapefile
    geomDims    = getfilevardimsizes(s,"geometry")
    numFeatures = geomDims(0)
    segments    = s->segments
    geometry    = s->geometry
    segsDims    = dimsizes(segments)

    ;---Read global attributes  
    geom_segIndex = s@geom_segIndex
    geom_numSegs  = s@geom_numSegs
    segs_xyzIndex = s@segs_xyzIndex
    segs_numPnts  = s@segs_numPnts

    ;---Read the lat/lon data off the shapefile
    lat = s->y
    lon = s->x

    ;---Debug prints
    print("Number of lat/lon values   = " + nlatlon)
    print("Number of lat/lon values")
    print("   that will be checked    = " + nii_latlon)

    ;---Create array to hold new data mask, and set all values to 0 initially.
    skip_check   = new(nlatlon,integer)
    skip_check   = 0

    ;---Read the state and county names off the file
    state  = s->NAME_1; State names
    county = s->NAME_2; County names

    ;---Grab index containing county.
    icounty = ind(state.eq.mystate.and.county.eq.mycounty)
    if (any(ismissing(icounty)))then
        print(state + county)
        print("couldn't find "+region+" in shapefile. exiting")
        exit
    end if
    print("Inspecting region " + region + "'...")

    ;---Some counties have multiple segments
    startSegment = geometry(icounty, geom_segIndex)
    numSegments  = geometry(icounty, geom_numSegs)
    do seg=startSegment, startSegment+numSegments-1
        startPT = segments(seg, segs_xyzIndex)
        endPT   = startPT + segments(seg, segs_numPnts) - 1

        ;---Loop through each point on data grid and see if it's in this county.
        do n=0,nii_latlon-1
            nn = ii_latlon(n)     ; Get index of point we're checking

            ; This "if" statement speeds up code, by making sure we don't
            ; needlessly check a lat/lon point if:
            ; 
            ; - we've already found it in another county
            ; - it doesn't fall within the general lat/lon box that covers this county

            if(skip_check(nn).or.\
               lat1d(nn).lt.min(lat(startPT:endPT)).or.\
               lat1d(nn).gt.max(lat(startPT:endPT)).or.\
               lon1d(nn).lt.min(lon(startPT:endPT)).or.\
               lon1d(nn).gt.max(lon(startPT:endPT))) 
               continue
            end if

            ;---Here's the check if the point is in the county.
            if(gc_inout(lat1d(nn),lon1d(nn),\
                        lat(startPT:endPT),lon(startPT:endPT))) then
              okay(nn) = 1b            ; This point is inside this county
              skip_check(nn)   = 1    ; Don't check this point again
            end if
        end do
    end do    ; End of collecting points for this county
    print("Writing cache " + cache)
    c = addfile(cache,"c")
    c->okay = okay ; can't store logical variable; store as byte. Return logical from this function
    return(okay.eq.1b)


    print("Unknown region:"+region)
    exit
end

undef("set_res_sf")
function set_res_sf (res:logical, ff:file, field:numeric, stride:integer)
; Assign lonCell and latCell to sfXArray and sfYArray, respectively.
; Based on whether field is cell or vertex-based and based on stride.
; Also smooth if field@nSmoothPasses > 0.
;===========================================================================
; This must be set before the calling script
; Couldn't figure out "external" call
; setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/

local nCells, nVertices, r2d, sfXArray, sfYArray
begin
	latCell        = ff->latCell
	verticesOnCell = ff->verticesOnCell
	dv             = dimsizes(verticesOnCell)
	maxEdges       = dv(1)
	verticesOnEdge = ff->verticesOnEdge
	dv            := dimsizes(verticesOnEdge)
	nEdges         = dv(0)
	nEdgesOnCell   = ff->nEdgesOnCell
	nCells         = dimsizes(ff->nEdgesOnCell)
	nVertices      = dimsizes(ff->latVertex)

	r2d = get_r2d("double") ; convert from radians to degrees

	if (any(isdim(field,"nVertices"))) then
        print("get_field_res::set_res_sf(): vertex-based")
		sfXArray = ff->lonVertex
		sfYArray = ff->latVertex
	end if
	if (any(isdim(field, "nCells"))) then
        print("get_field_res::set_res_sf(): cell-based")
		sfXArray = ff->lonCell
		sfYArray = latCell ; latCell already assigned above
	end if
    if(.not.isvar("sfXArray"))then
        print("get_field_res/set_res_sf(): did not find sfXArray") 
        print(getvardims(field))
        exit
    end if
	res@sfXArray := sfXArray(::stride) * r2d
	res@sfYArray := sfYArray(::stride) * r2d

	
	; Smooth field if resource attribute "nSmoothPasses" was set in get_field_res.ncl
    ; After smoothing, delete the resource attribute and add a "nSmoothPasses" 
    ; attribute to the field array itself.
	if (isatt(res,"nSmoothPasses")) then
		nSmoothPasses = res@nSmoothPasses
        ; if avg cell size < 15km (1.1e+08 m^2) double smoothing passes (good for convection resolving mesh)
        if (avg(ff->areaCell) .lt. 1.e+08) then 
		    nSmoothPasses = nSmoothPasses*2
        end if

		; Remove nSmoothPasses attribute from resource variable
		delete(res@nSmoothPasses)
		tmp := todouble(field) ; mpas_filter_cells expects double
		printMinMax(tmp,False)
        if(isatt(tmp, "_FillValue"))then
            missing_value = tmp@_FillValue
        else
            missing_value = default_fillvalue(typeof(tmp))
        end if

		if (field!0 .eq. "nVertices") then
			if (nSmoothPasses.lt.50) then
                mpas_filter_vertices(ff->edgesOnVertex,verticesOnEdge,nVertices,nEdges,tmp, nSmoothPasses, missing_value )
            else
                fast(ff->edgesOnVertex,verticesOnEdge,nVertices,nEdges,tmp, nSmoothPasses )
            end if
		else
			mpas_filter_cells(nEdgesOnCell, ff->cellsOnCell, maxEdges, nCells, tmp, nSmoothPasses, missing_value )
		end if
		printMinMax(tmp,False)
		field= tofloat(tmp)
		; Add nSmoothPasses attribute from resource variable (to show it was done).
		field@nSmoothPasses = nSmoothPasses
		; field@name should have already been defined above in get_cn_res or get_field_res.
		res@cnInfoLabelString = field@name+" contours from $CMN$ to $CMX$ by $CIU$ "+field@units+", "+tostring(nSmoothPasses)+" smoothing passes"
		if (res@cnFillOn) then
			res@cnInfoLabelOn = True ; gsn_* functions set this to False by default. 
			; Tried changing res@cnInfoLabelZone but no effect.
            ; But cnInfoLabelOrthogonalPosF works. 
		end if
		res@cnInfoLabelFontHeightF = 0.007
		print("finished "+tostring(nSmoothPasses)+" smoothing passes on "+field@long_name)
	end if

	return(res)
end

