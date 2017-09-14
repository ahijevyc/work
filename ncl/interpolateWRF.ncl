;======================================================================
; Originally copied from ESMF_regrid_5.ncl
;
; Concepts illustrated:
;   - Interpolating from one grid to another using ESMF_regrid
;   - Interpolating data from a WRF grid to a rectilinear grid
;   - Using functions for cleaner code
;======================================================================
; For more information about ESMF:
;
;        http://www.earthsystemmodeling.org/
;======================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRF_contributed.ncl"

;======================================================================
; This procedure plots both the original data and regridded data
; as a panel plot, given the data, variable name, and contour levels.
;======================================================================
undef("plot_data")
procedure plot_data(wks,data_orig,data_regrid,VARNAME,cnlevels)
local tdims, n, res, pres, plot_orig, plot_r
begin
   print("--------------------------------------------------")
   print("Generating plot(s) for variable '" + VARNAME + "'...")

;---Set some common resources
    res                   = True

    res@gsnMaximize       = True

    res@cnFillOn          = True
    res@cnLinesOn         = False
    res@cnLineLabelsOn    = False

    res@cnLevelSelectionMode = "ExplicitLevels"
    res@cnLevels             = cnlevels

    res@mpFillOn          = False

    res@mpMinLatF         = min(data_regrid&lat)
    res@mpMaxLatF         = max(data_regrid&lat)
    res@mpMinLonF         = min(data_regrid&lon)
    res@mpMaxLonF         = max(data_regrid&lon)
    res@mpCenterLonF      = (min(data_regrid&lon)+max(data_regrid&lon))*0.5
    res@mpCenterLatF      = (min(data_regrid&lat)+max(data_regrid&lat))*0.5

    res@lbBoxLinesOn      = False

    res@gsnAddCyclic      = False

    res@gsnDraw         = False
    res@gsnFrame        = False
    res@lbLabelBarOn    = False

;---Set some panel resources
    pres                    = True
    pres@gsnMaximize        = True
    pres@gsnPanelLabelBar   = True
    pres@lbLabelFontHeightF = 0.01
    pres@lbBoxLinesOn       = False

    tdims       = dimsizes(data_orig)

;---Loop across the desired times and plot TMP and U

;---Create plot for original data

    res@tiMainString    = "Original WRF grid"

    res@gsnLeftString   = VARNAME + " (" + \
                          str_join(tostring(tdims)," x ") + ")"
 
    plot_orig = gsn_csm_contour_map(wks,data_orig(0,:,:),res)  

;---Create plot for regridded data
    res@tiMainString = "Regridded to rectilinear grid"

    res@gsnLeftString = VARNAME + " regridded (" + \
                        str_join(tostring(tdims)," x ") + ")"


    plot_regrid = gsn_csm_contour_map(wks,data_regrid(0,:,:),res)  


;---Panel both sets of plots
    gsn_panel(wks,(/plot_orig,plot_regrid/),(/2,1/),pres)
end

;======================================================================
; The main code
;======================================================================

begin

WRITE_RESULTS = True
PLOT_RESULTS = True

;---Input file
    if(.not.isvar("srcFileName"))then
        srcFileName = "wrfout_d01_2008-09-09_00:00:00"
    end if
    ; Grab columns 7-9 and use this as the grid name (e.g. "d01").
    grid = str_get_cols(systemfunc("basename "+srcFileName),7,9)
    dir = "./"
    domain = "IKE."+grid

;   Define the destination lat/lon grid
;---The fspan function takes a min and max value, and the number of increments.
;   and returns a 1-D array between min and max with n number of equally-spaced increments 
    if(grid.eq."d01")then
        lat = fspan(  0., 45.,45*3+1)
        lon = fspan(250., 310,60*3+1)
    end if
    if(grid.eq."d02")then
        lat = fspan(  0., 45.,45*8+1)
        lon = fspan(250., 310,60*8+1)
    end if
    if(grid.eq."d03")then
        lat = fspan( 15., 40.,25*24+1)
        lon = fspan(255.,285.,30*24+1)
    end if
    sfile = addfile(srcFileName,"r")

    Opt                = True
    Opt@SrcTitle       = "WRF grid"   ; optional

    Opt@ForceOverwrite = False
    ;;Opt@PrintTimings = True

    time = wrf_times_c(sfile->Times,1)
    stime = tostring(sfile->Times)
    print(stime)

	Opt@WgtFileName       = dir + "esmf_wgt_"+domain+"_"+stime+".nc"
	if(isfilepresent(Opt@WgtFileName))then
		Opt@SkipWgtGen = True
	end if
	Opt@DstFileName       = dir + "esmf_dst_"+domain+".nc"
	if(isfilepresent(Opt@DstFileName))then
		Opt@SkipDstGrid = True
	end if
	Opt@SrcFileName       = dir + "esmf_src_"+domain+"_"+stime+".nc"
	if(isfilepresent(Opt@SrcFileName))then
		Opt@SkipSrcGrid = True
	end if

    itime = 0
    slp = wrf_user_getvar(sfile,"slp",-1)
    ; Don't use uvmet10 - it already looks like u and v are earth-relative
    if(False)then
        UV10 = wrf_user_getvar(sfile,"uvmet10",itime)
        u10 = UV10(0,:,:)
        v10 = UV10(1,:,:)
    end if
    u10 = wrf_user_getvar(sfile,"U10",-1)
    v10 = wrf_user_getvar(sfile,"V10",-1)


;---Get the source lat/lon grid
    lat2d = wrf_user_getvar(sfile,"lat",itime)
    lon2d = wrf_user_getvar(sfile,"lon",itime)
    dims  = dimsizes(lat2d)
    nlat  = dims(0)
    nlon  = dims(1)

    lon2d = where(lon2d.lt.0,360+lon2d,lon2d)

    slp@lat2d = lat2d              ; This information will be used by
    slp@lon2d = lon2d              ; ESMF_regrid for the source grid
    u10@lat2d = lat2d
    u10@lon2d = lon2d
    v10@lat2d = lat2d
    v10@lon2d = lon2d


    Opt@DstGridType          = "rectilinear"
    Opt@DstGridLat           = lat
    Opt@DstGridLon           = lon

    Opt@InterpMethod         = "bilinear"
    Opt@SrcRegional          = True
    Opt@DstRegional          = True

    slp_regrid          = ESMF_regrid(slp,Opt)  
    u10_regrid          = ESMF_regrid(u10,Opt)  
    v10_regrid          = ESMF_regrid(v10,Opt) 

;---Reset 0 values to missing values.
    slp@_FillValue = default_fillvalue(typeof(slp_regrid))
    u10@_FillValue = default_fillvalue(typeof(u10_regrid))
    v10@_FillValue = default_fillvalue(typeof(v10_regrid))

    slp_regrid     = where(slp_regrid.eq.0.0,slp_regrid@_FillValue,\
                           slp_regrid)
    ; Leave u/v zeros as zeros.

;----------------------------------------------------------------------
; Plotting section
;----------------------------------------------------------------------
    if(PLOT_RESULTS)then
        wks = gsn_open_wks("ps","ESMF_regrid")
        gsn_define_colormap(wks,"WhViBlGrYeOrReWh")

        tmp_levels = ispan(30,48,2)
        slp_levels = ispan(970,1020,2)
        u_levels   = ispan(-50,64,2)
    ;
        plot_data(wks, slp,slp_regrid,"slp", slp_levels)
        plot_data(wks, u10,u10_regrid,"u10",  u_levels)
        plot_data(wks, v10,v10_regrid,"v10",  u_levels)
    end if

;----------------------------------------------------------------------
;     Write the regridded data to a NetCDF file
;----------------------------------------------------------------------
    if(WRITE_RESULTS) then
      rgrdFileName = srcFileName+"_latlon.nc"
      system("rm -f " + rgrdFileName)
      rgrd_nc = addfile(rgrdFileName,"c")

;---Create variable to hold global file attributes
      global = True
      copy_VarAtts(sfile, global)

      if (isatt(sfile,"title")) then
        global@TITLE = "REMAPPED: " + sfile@title
      end if
      global@remap         = "NCL: ESMF_regrid_with_weights (NCL version '" + \
                             get_ncl_version() + "')"
      global@remap_method  = Opt@InterpMethod
      global@creation_date = systemfunc("date")
    
      fileattdef( rgrd_nc, global )        ; copy global file attributes
      filedimdef(rgrd_nc,"TIME",-1,True)   ; force an unlimited dimension
;
; Write variables to file. Coordinate arrays will be written 
; automatically
;
      rgrd_nc->slp = slp_regrid
      rgrd_nc->u10 = u10_regrid
      rgrd_nc->v10 = v10_regrid
      rgrd_nc->Time = time
      delete(rgrd_nc)
    end if

end
