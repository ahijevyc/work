load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/length_scale.ncl"

begin

	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	idir = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/"+modelstr+"/" ; "coldstart_extend" and ADCIRC control RUN
	; modelstr has to be "coldstart_extend" one time - you will get an error but dont worry
	if(modelstr.eq."NOS")then
		idir = "/glade/scratch/fossell/ADCIRC/NOS/ikr09/NOS_OWI/" ; NOS run
	end if
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+modelstr+"/"
	if(.not.isvar("notide"))then
		notide = False
	end if
	; zoom level
	if(.not.isdefined("zoom"))then
		zoom = 0 
	end if
	offshore_depth_threshold = 20.

	if (zoom.eq.-1) then
			MinLonF             = -99
			MaxLonF             = -81
			MinLatF             = 19.
			MaxLatF             = 31.
			LabelFontHeightF    = 0.0
			GeophysicalLineThicknessF = 2
	end if
	if (zoom.eq.0) then
			MinLonF             = -99
			MaxLonF             = -85
			MinLatF             = 21
			MaxLatF             = 31.
			LabelFontHeightF    = 0.0
			GeophysicalLineThicknessF = 2
	end if
	if (zoom.eq.1) then
			MinLonF             = -97.
			MaxLonF             = -89.
			MinLatF             = 27.5
			MaxLatF             = 31.
			LabelFontHeightF    = 0.0
			GeophysicalLineThicknessF = 3
	end if
	if (zoom.eq.2) then
			MinLonF             = -94.3
			MaxLonF             = -93.55
			MinLatF             = 29.45
			MaxLatF             = 30.25
			LabelFontHeightF    = 0.01
			GeophysicalLineThicknessF = 3
	end if
	if (zoom.eq.4) then
			MinLonF             = -97.1
			MaxLonF             = -96.8
			MinLatF             = 28.
			MaxLatF             = 28.2
			LabelFontHeightF    = 0.015
			GeophysicalLineThicknessF = 3
	end if

	print("opening "+idir+"maxele.63.nc")
	f = addfile(idir+"maxele.63.nc","r")

	if(notide)then
		print("not setup for notide")
		exit
	end if

	k = ind(f->x .ge.MinLonF.and.f->x .le.MaxLonF.and.f->y .ge.MinLatF.and.f->y .le.MaxLatF)

	sm = ".temporarysmallgrid"
	system("rm -v "+sm+".nc") 
	g = addfile(sm+".nc","c")
	g->zeta_max = f->zeta_max(k)
	g->depth = f->depth(k)
	g->x = f->x(k)
	g->y = f->y(k)
	; get area asssociated with each node (file created by Michael Duda)
	a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
	g->areaCell = a->areaCell(k)

	; Read file that lists nodes where surface submergence state is 1
	sfc_sub_state_file = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/control/surface_submergence_state_14040.txt"
	lines = asciiread(sfc_sub_state_file, -1, "integer")
	inodes = lines(::2)
	sfc_sub_state = new(dimsizes(f->zeta_max), "integer")
	sfc_sub_state(inodes) = 1
	g->sfc_sub_state = sfc_sub_state(k)
	delete(g)
	delete(k)
	delete(a)
	f = addfile(sm+".nc","r")
	outfile = workdir+modelstr+".notide"+notide+".zoom"+zoom
	wks = gsn_open_wks("png",outfile)
	Iketrack = readAsciiTable("/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/control/IkeTrack.txt",2,"float",0) ; same IkeTrack for control run and NOS
	trackfile = idir+"fort.22"
	if(modelstr.eq."NOS")then ; fort.22 is quite different for the NOS run. it don't have lat/lon of track.
		trackfile =  "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51/control/fort.22"
	end if
	if(fileexists(trackfile))then
		print("reading "+trackfile)
		lines := asciiread(trackfile,-1,"string")
		delim = ","
		tracklon = -1 * tofloat(str_get_field(lines, 8, delim))/10.
		tracklat = tofloat(str_get_field(lines, 7, delim))/10.
		tt := str_get_field(lines, 3, delim)
		year   := tointeger(str_get_cols(tt, 1, 4))
		month  := tointeger(str_get_cols(tt, 5, 6))
		day    := tointeger(str_get_cols(tt, 7, 8))
		hour   := tointeger(str_get_cols(tt, 9,10))
		minute := hour
		minute = 0
		second := hour
		second = 0
	end if



	nnodes = dimsizes(f->zeta_max) ; number of nodes
	stride=tointeger(max( (/ 1., nnodes^0.4/100 /) ))
	zeta_max = f->zeta_max(::stride)
	depth = f->depth(::stride)
	sfc_sub_state := f->sfc_sub_state(::stride)

	Re = 6371.; radius of Earth in km
	areaCell := f->areaCell(::stride) * Re^2.

	gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
	res                          = True
	res@cnLinesOn                = False
	res@cnLevelSelectionMode     = "ManualLevels"
	res@cnMinLevelValF           =  0. 
	res@cnMaxLevelValF           =  5.
	res@cnLevelSpacingF          =  0.5

	res@sfFirstNodeIndex         = 1
	res@sfXArray                 = f->x(::stride)
	res@sfYArray                 = f->y(::stride)
	res@sfDataArray              = zeta_max

	res@cnFillOn                 = True
	res@cnFillMode               = "RasterFill"
	res@cnLineLabelsOn           = True
	res@cnLineLabelPlacementMode = "Constant"
	res@cnLineLabelFontHeightF   = LabelFontHeightF
	res@lbLabelAutoStride        = True
	res@lbTitleString            = zeta_max@long_name + " (meters)"
	res@lbTitleFontHeightF       = 0.018
	res@lbTitlePosition          = "Bottom"

	res@gsnCenterString          = modelstr
	res@gsnCenterStringOrthogonalPosF = 0.1
	res@gsnRightString           = ""

	; nearshore contour
	nsres                      = True
	nsres@cnInfoLabelString    = "$CMX$ meter depth contour"
	nsres@cnLevelSelectionMode = "ExplicitLevels"
	nsres@cnLineDashPattern    = "Dash"
	nsres@cnLevels             = (/offshore_depth_threshold/)
	nsres@cnLineThicknessF     = 3
	nsres@cnLineColor          = "red"
	nsres@tiMainString         = ""
	nsres@sfFirstNodeIndex     = res@sfFirstNodeIndex
	nsres@sfXArray             = res@sfXArray
	nsres@sfYArray             = res@sfYArray



	; First create just a contour plot so we can retrieve
	; the start/end limits of the data and define a good plot window.
	; Don't draw the contour plot or advance the frame.
	res@gsnDraw  = False
	res@gsnFrame = False
	contour = gsn_csm_contour(wks,zeta_max,res)

	; Make sure gsnDraw and gsnFrame are on for the next plot.
	res@gsnDraw  = True

	; Get ready to overlay on a cylindrical equidistant map.
	; Retrieve the actual start and end limits of the data
	getvalues contour@data
		"sfXCActualStartF" : xs
		"sfXCActualEndF"   : xe
		"sfYCActualStartF" : ys
		"sfYCActualEndF"   : ye
	end getvalues
	getvalues contour
		"cnLevels" : cnLevels
		"cnFillColors" : cnFillColors
	end getvalues

	res@mpDataBaseVersion     = "HighRes"     ; "MediumRes" will run faster.
	res@mpLimitMode           = "LatLon"
	res@mpMinLonF             = xs
	res@mpMaxLonF             = xe
	res@mpMinLatF             = ys
	res@mpMaxLatF             = ye

	res@mpMinLonF             = MinLonF
	res@mpMaxLonF             = MaxLonF
	res@mpMinLatF             = MinLatF
	res@mpMaxLatF             = MaxLatF
	res@mpPerimOn             = False
	res@mpGeophysicalLineThicknessF = GeophysicalLineThicknessF
	res@pmTickMarkDisplayMode    = "Always"    ; Turn on map tickmarks.
	lres                      = True
	lres@gsLineThicknessF     =  4.

	; Background filled contour with near-shore contour.
	map := gsn_csm_contour_map_overlay(wks,zeta_max,depth,res,nsres)
	txres = True
	txres@txFontHeightF = 0.012
	txres@txJust        = "BottomLeft"
	gsn_text_ndc(wks, "domain "+tostring(zoom)+" every "+tostring(stride)+" nodes~C~"+systemfunc("date"),0.01,0.01,txres)
	; Draw a dot on each node.
	mkres                   = True
	mkres@gsMarkerIndex     = 1
	mkres@gsMarkerSizeF     = 0.001
	mkres@gsMarkerOpacityF  = 0.007
	if(zoom.eq.4) then
		mkres@gsMarkerSizeF     = 0.003
		mkres@gsMarkerOpacityF  = 0.75
		;print("labeling area of nodes")
		;gsn_text(wks,map,sprintf("%2.0f",areaCell*100),res@sfXArray,res@sfYArray,mkres)
		reddot = mkres
		reddot@gsMarkerColor     = "dark green"
		reddot@gsMarkerSizeF     = 0.02
		tmp := ind(depth.le.0)
		gsn_polymarker(wks,map,res@sfXArray(tmp),res@sfYArray(tmp),reddot)
		tmp := ind(depth.ge.0.and.sfc_sub_state.eq.1)
		reddot@gsMarkerColor     = "red"
		reddot@gsMarkerSizeF     = 0.018
		gsn_polymarker(wks,map,res@sfXArray(tmp),res@sfYArray(tmp),reddot)
	end if
	gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,mkres)
	print("dotted nodes")

	; Annotate surge station observations
	obs_file = "./control/Ike_2008_surge_station_obs.csv"
	lines := asciiread(obs_file, -1, "string")
	strs = str_split_csv(lines, ",", 0)
	nums = tofloat(strs)
	;nums@_FillValue = -9999.0 ; no fill value in the excel spreadsheet.
	mkres@gsMarkerIndex = 16
	mkres@gsMarkerOpacityF  = 0.75
	mkres@gsMarkerColor = "dark green"
	mkres@gsMarkerSizeF = 0.004
	x = nums(:,2)
	y = nums(:,1)
	gsn_polymarker(wks,map,x,y,mkres)
	mkres@txFontHeightF = res@cnLineLabelFontHeightF * 1.5
	mkres@txFontColor = mkres@gsMarkerColor
	mkres@txJust = "CenterLeft"
	gsn_text(wks,map," "+str_get_cols(lines,0,3),x,y,mkres)
	gsn_polyline(wks,map,tracklon,tracklat,lres)
	
	
	; draw hollow circle (NhlTmarkerIndex=4) around node
	mkres@gsMarkerColor = "black"
	mkres@gsMarkerIndex = 4
	count = num(x.ge.xs.and.x.le.xe.and.y.ge.ys.and.y.le.ye)
	if(count.gt.1)then
		obs = new(count, "float")
		model = new(count, typeof(res@sfDataArray))
		count = 0
		; for each surge station observation
		do n = 0, dimsizes(lines)-1
			 if (x(n).ge.xs.and.x(n).le.xe.and.y(n).ge.ys.and.y(n).le.ye)then
				; print(nums(n,0))
				obs(count) = nums(n,0)
				; Find closest node to surge station
				dist = gc_latlon(res@sfYArray,res@sfXArray,onedtond(y(n),dimsizes(res@sfYArray)),onedtond(x(n),dimsizes(res@sfXArray)),2,-4)
				;dist = (x(n) - res@sfXArray)^2. + (y(n)-res@sfYArray)^2.
				i = minind(dist)
				;print(res@sfDataArray(i))
				model(count) = res@sfDataArray(i)
				; draw hollow circle (NhlTmarkerIndex=4) around node
				gsn_polymarker(wks,map,res@sfXArray(i),res@sfYArray(i),mkres)
				count = count + 1
			 end if
		end do
		rc = regline_stats(obs, model)
		;print(rc)
		data = new ( (/3, dimsizes(obs)/), typeof(model))
		data(0,:) = model
		data(1,:) = rc*(obs - rc@xave) + rc@yave
		data(2,:) = obs ; 1:1 line (obs vs obs)
		;print(data)
		xyres                 = True                   ; plot mods desired

		; this controls the size and location of the first plot
		xyres@vpXF            = 0.81         
		xyres@vpWidthF        = 0.18	    
		xyres@vpYF            = 0.97
		xyres@vpHeightF       = 0.18 

		xyres@gsnMaximize         = False                  ; maximize plot in frame
		xyres@xyMarkLineModes     = (/"Markers","Lines","Lines"/)  ; choose which have markers
		xyres@xyMarkers           = 16                     ; choose type of marker 
		xyres@xyMarkerColor       = "dark green"                ; Marker color
		xyres@xyMarkerSizeF       = 0.005                  ; Marker size (default 0.01)
		xyres@xyDashPatterns      = (/"Solid","Solid","Solid"/)                
		xyres@xyLineThicknesses   = (/1,1,2/)          
		xyres@xyLineColors        = (/xyres@xyMarkerColor,xyres@xyMarkerColor,"black"/)
		xyres@xyLabelMode         = "Custom"
		xyres@gsnShape            = True

		xyres@tiMainString        = "r~S~2~N~="+sprintf("%4.2f",rc@r2)+", norm. bias="+sprintf("%4.1f",rc@Yavg/rc@Xavg)
		xyres@tiYAxisString        = modelstr + "~C~" + zeta_max@long_name + " (m above MSL)"
		xyres@tiXAxisString        = "SURGEDAT Obs (m above MSL)"

		plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot
	
		; 2nd page - full page scatterplot
		xyres@gsnMaximize          = True               ; maximize plot in frame
		xyres@pmLegendDisplayMode  = "Always"
		xyres@pmLegendSide         = "Bottom"
		xyres@xyExplicitLegendLabels = (/"(obs,model)","best-fit","1:1"/)
		xyres@xyExplicitLabels     = xyres@xyExplicitLegendLabels
		plot  = gsn_csm_xy (wks,obs,data,xyres)        ; create plot
	else
		frame(wks)   
	end if

	; Max inundation. You can calculate volume but it doesn't make sense. This is a max over time at each point. 
	; The inundation is never actually this much at any time.  The max water height is spread over time as it washes over the land.
	; That's why the number here is so much larger than the number in the instantaneous bulge_timeseries. 
	; Mask ocean, but not low-lying land cells below MSL.
	inundation = mask(zeta_max+depth,depth.le.0.or.(depth.ge.0.and.sfc_sub_state.eq.1),True)
	STATX = stat_dispersion(inundation,False)

	; IKE landfall coordinates in control run.
	clat = 29.3
	clon = -94.7
	ring_km = 223.; length scale (km) of control run max. inundation with notide=True
	dist := gc_latlon(res@sfYArray,res@sfXArray,onedtond(clat,dimsizes(res@sfYArray)),onedtond(clon,dimsizes(res@sfXArray)),2,-4)
	; Only count nodes within ring. Ignore dry-start nodes
	inundation_in_ring = mask(inundation,depth.le.0.and.dist.lt.ring_km,True)

	inundation@long_name = "maximum inundation"
	inundation@units     = "m"
	res@sfDataArray      = inundation
	title = "inundation swath volume in domain = "+sprintf("%.1f", sum(stride*areaCell*inundation/1000.))+" km~S~3~N~~C~"+\
		"in ring = "+sprintf("%.1f", sum(stride*areaCell*inundation_in_ring/1000.))+" km~S~3~N~~C~"+\
		"inundation depth 75th percentile = "+sprintf("%.1f",STATX(10))+" m~C~"+\
		"inundation depth 90th percentile = "+sprintf("%.1f",STATX(13))+" m~C~"+\
		"inundation depth 95th percentile = "+sprintf("%.1f",STATX(25))+" m~C~"+\
		"inundation depth 99th percentile = "+sprintf("%.1f",STATX(26))+" m"
	map := gsn_csm_contour_map(wks,inundation,res)
	if(zoom.eq.4) then
		tmp := ind(inundation.ge.0.5)
		mkres@gsMarkerIndex     = 1
		print("labeling nodes")
		mkres@txFontHeightF = 0.007
		mkres@txJust = "CenterCenter"
		gsn_text(wks,map,sprintf("%3.1f",inundation(tmp)),res@sfXArray(tmp),res@sfYArray(tmp),mkres)
		gsn_polymarker(wks,map,res@sfXArray,res@sfYArray,mkres)
		print("dotted nodes")
	end if
	ring_res                        = True
	ring_res@gsLineLabelFontHeightF = 0.007
	ring_res@gsLineLabelString = sprintf("%4.0fkm", ring_km)
	; Draw ring around storm
	; these variables hold the circle lat/lons around the storm
	rglat = new(80,float)
	rglon = new(80,float)
	nggcog(clat,clon,ring_km/Re*180./3.141592,rglat,rglon)
	gsn_polyline(wks, map, rglon, rglat, ring_res)

	volume = stride*areaCell/1000.*inundation
	; define array of volume fraction thresholds (0-1) to plot
	;fracts = (/ 0.9, 0.95, 0.99 /)
	;do ifract=0,dimsizes(fracts)-1
	;	fract = fracts(ifract)
	;	length_scale_km = length_scale(volume,dist,fract)
	;	ring_res@gsLineLabelString = sprintf("%2.0f",fract*100)+"% "+sprintf("%4.0fkm", length_scale_km)
	;	nggcog(clat,clon,tofloat(length_scale_km)/Re*180./3.141592,rglat,rglon)
	;	gsn_polyline(wks, map, rglon, rglat, ring_res)
	;end do
		
	gsn_polyline(wks,map,tracklon,tracklat,lres)
	gsn_text_ndc(wks, "domain "+tostring(zoom)+" every "+tostring(stride)+" nodes~C~"+systemfunc("date"),0.01,0.01,txres)
	txres@txJust        = "TopLeft"
	gsn_text_ndc(wks, title,0.01,0.99,txres)
	frame(wks)

	hres                          = True
	hres@gsnHistogramBinIntervals = cnLevels
	hres@gsnHistogramMinMaxBinsOn = True
	hres@tiMainString             = res@gsnCenterString
	hres@gsFillColor              = cnFillColors
	plot := gsn_histogram(wks,inundation,hres)

	print("finished "+outfile)
	
end

