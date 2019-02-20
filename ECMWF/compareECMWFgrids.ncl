;=============================================================================================
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/derived_fields.ncl"
load "/glade/work/ahijevyc/ncl/timestamp.ncl"
;=============================================================================================

; Copied from /glade/work/ahijevyc/GFS/compare2_ECMWFanalysis.ncl in Feb 2019

; compare ECMWF ensemble forecast on 0.5 grid to 0.25 deg grid (or even 0.15 deg grid) 

; use /glade/work/ahijevyc/ECMWF/download.py to obtain ECMWF files

begin
if(.not.isvar("date")) then
	date = "2017090800"
end if
ymd=str_get_cols(date,0,7)
hhmm=str_get_cols(date,8,9)+"00"

field = "speed_10m"
if(.not.isvar("fhr")) then 
	fhr = 66
end if
idir = "/glade/scratch/ahijevyc/ECMWF/"+date+"/"
grid_spacings = (/ "0p15", "0p25", "0p5" /)

ms2kt = 1.94384
do igrid = 0, dimsizes(grid_spacings)-1
    grid_spacing = grid_spacings(igrid) 
    output_file = idir + grid_spacing + ".png"
    wks = gsn_open_wks("png",output_file)

    file_ncl = idir + grid_spacing + date + "_sfc.grb"
    print("opening "+file_ncl)
    ff = addfile(file_ncl,"r")
    if(ismissing(ff))then
        print(ff)
        print("is missing")
    end if

    varnames = getfilevarnames(ff)
    uvar = "10u_P1_L103_GLL0"
    vvar = "10v_P1_L103_GLL0"
    ;print(varnames)
    contour_string = "msl_P1_L101_GLL0"
    ;printVarSummary(ff->$contour_string$)
    cntr := ff->$contour_string$({forecast_time0|fhr},lat_0|:,lon_0|:)

    year = toint(str_get_cols(date,0,3))
    month = toint(str_get_cols(date,4,5))
    day = toint(str_get_cols(date,6,7))
    hour = toint(str_get_cols(date,8,9))
    init := cd_inv_calendar(year,month,day,hour,0,0,"hours since 1800-01-01 00:00",0)
    valid = init + fhr

    ; Read u and v. 
    u := ff->$uvar$({forecast_time0|fhr},lat_0|:,lon_0|:)
    v := ff->$vvar$({forecast_time0|fhr},lat_0|:,lon_0|:)
    fp := wind_speed(u, v)
    printVarSummary(fp)
    printMinMax(fp,False)
    
    ;SET RESOURCES:
    res := get_field_res(wks, field, fp)

    res = set_res_mp(res, "IRMA_zoom2")
    ;print(res)
    res@tiMainString = "ECMWF member 31 "+grid_spacing+"deg~C~initialized "+date+"  " +sprintf("%.0f",fhr)+"h fcst"
    ;printVarSummary(fp)
    printMinMax(fp,False)
    plot = gsn_csm_contour_map(wks,fp,res)

    ; MSLP Contours
    sres = get_res_cn("al",contour_string,cntr)
    sres@cnLineColor = "darkgreen"
    sres@cnLevelSpacingF = 8. 
    sres@cnLineThicknessF = 3.
    plot_ov := gsn_csm_contour(wks,cntr,sres)
    overlay(plot, plot_ov)

    ; Cosmetic changes for wind barbs
    vres = True
    vres@gsnDraw = False
    vres@gsnFrame = False
    vres@vcRefLengthF    = 0.02
    vres@vcGlyphStyle = "WindBarb"
    vres@vcPositionMode = "ArrowHead"
    vres@vcMinDistanceF = 0.02
    vres@vcRefAnnoOn = True
    vres@vcRefAnnoSide = "Right"
    vres@vcWindBarbLineThicknessF = 1.6

    ; Important changes and additions for wind barbs
    vres@vcWindBarbScaleFactorF = ms2kt ; u and v components are still in m/s
    vres@vcRefAnnoString1 = "full barb = 10 kt"
    vres@vcRefAnnoString2 = "pennant = 50 kt"
    vres@gsnLeftString = ""  ; you don't want to label with u@long_name and u@units
    vres@gsnRightString = "" ; after all, u is still in m/s
    plot_ov := gsn_csm_vector(wks,u,v,vres)
    overlay(plot,plot_ov)
    
    draw(plot)
    frame(wks)
    return_val = add_timestamp(output_file)

end do ; grid spacings
end

