;=============================================================================================
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/work/ahijevyc/ncl/derived_fields.ncl"
load "/glade/work/ahijevyc/ncl/find_match.ncl"
load "/glade/work/ahijevyc/ncl/timestamp.ncl"
;=============================================================================================

; Copied from /glade/work/ahijevyc/GFS/compare2_ECMWFanalysis.ncl in Feb 2019

; compare ECMWF ensemble forecast on 0.5 grid to 0.25 deg grid or 0.15 deg or even 0.075 deg grid 

; use /glade/work/ahijevyc/ECMWF/download.py to obtain ECMWF files

begin
if(.not.isvar("date")) then
	date = "2017090812"
end if
ymd=str_get_cols(date,0,7)
hhmm=str_get_cols(date,8,9)+"00"

field = "speed_10m"

if(.not.isvar("fhr")) then 
	fhr = 60
end if

if(.not.isvar("ens")) then 
	ens = "PF50"
end if


if(.not.isvar("zoom")) then 
	zoom = 0
end if

grid_spacings = (/ "0p15", "0p25", "0p5" /)
grid_spacings := (/ "0p125" /)

ms2kt = 1.94384
do igrid = 0, dimsizes(grid_spacings)-1
    grid_spacing = grid_spacings(igrid) 
    idir = "/glade/scratch/ahijevyc/ECMWF/"+grid_spacing+"/"+date+"/"+ens+"/"
    output_file = idir + grid_spacing +"."+sprintf("hr%03.0f", fhr) + ".png"
    print(output_file)
    wks = gsn_open_wks("png",output_file)

    ;file_ncl = idir + grid_spacing + date + "_sfc.grb"
    file_ncl = idir + "SFC_"+ ymd+ "_1200.grb"
    print("opening "+file_ncl)
    ff = addfile(file_ncl,"r")
    if(ismissing(ff))then
        print(ff)
        print("is missing")
    end if

    varnames = getfilevarnames(ff)
    uvars = (/ "10u_P1_L103_GLL0", "10U_GDS0_SFC" /)
    vvars = (/ "10v_P1_L103_GLL0", "10V_GDS0_SFC" /)
    pvars = (/ "msl_P1_L101_GLL0", "MSL_GDS0_SFC" /)
    latdims = (/ "lat_0", "g0_lat_1" /) 
    londims = (/ "lon_0", "g0_lon_2" /) 
    uvar   = find_match_var(uvars, ff)
    vvar   = find_match_var(vvars, ff)
    pvar   = find_match_var(pvars, ff)
    latdim = find_match_dim(latdims, ff)
    londim = find_match_dim(londims, ff)
    ;print(varnames)
    contour_string = pvar
    ;printVarSummary(ff->$contour_string$)
    cntr := ff->$contour_string$({forecast_time0|fhr},$latdim$|:,$londim$|:)

    year = toint(str_get_cols(date,0,3))
    month = toint(str_get_cols(date,4,5))
    day = toint(str_get_cols(date,6,7))
    hour = toint(str_get_cols(date,8,9))
    init := cd_inv_calendar(year,month,day,hour,0,0,"hours since 1800-01-01 00:00",0)
    valid = init + fhr

    ; Read u and v. 
    u := ff->$uvar$({forecast_time0|fhr},$latdim$|:,$londim$|:)
    v := ff->$vvar$({forecast_time0|fhr},$latdim$|:,$londim$|:)
    fp := wind_speed(u, v)
    printVarSummary(fp)
    printMinMax(fp,False)
    
    ;SET RESOURCES:
    res := get_field_res(wks, field, fp)
    res@cnLevelSelectionMode = "ExplicitLevels"
    res@cnLevels   = (/ 34, 50, 64 /)
    res@cnFillColors = (/ (/1,1,1/), (/.35,.45,.82/), (/.86,.98,0./), (/.93,.07,.04/) /)

    res = set_res_mp(res, "IRMA_zoom"+zoom)
    ;print(res)
    res@gsnAddCyclic = False
    res@tiMainString = "ECMWF"+grid_spacing+"deg~C~initialized "+date+"  " +sprintf("%.0f",fhr)+"h fcst"
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

