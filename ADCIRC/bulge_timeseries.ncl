load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/time_axis_labels.ncl"
load "/glade/p/work/ahijevyc/ncl/date_str.ncl"
load "/glade/p/work/ahijevyc/ncl/length_scale.ncl"

; Each time you change lat/lon bounds, call program with "newgrid=True"

begin
	; for some reason putting systemfunc("date") in the do loop resulted in random crashes
	currentdate = systemfunc("date")
	if(.not.isvar("modelstr"))then
		modelstr = "control"
	end if
	idir = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/v51_additive_perts/"+modelstr+"/" 
	; modelstr has to be "coldstart_extend" one time - you will get an error but dont worry
	workdir = "/glade/p/work/ahijevyc/ADCIRC/"+modelstr+"/"
	if(.not.isvar("notide"))then
		notide = False
	end if
	if(.not.isvar("newgrid"))then
		newgrid = False
	end if
	thresh = 0.5 ; inundation threshold
	thresh_string = sprintf("%4.2fm", thresh)

	f = addfile(idir+"fort.63.nc","r")

	MinLonF = -99.
	MaxLonF = -87.
	MinLatF =  25.
	MaxLatF =  31.
	if (str_get_cols(modelstr,-6,-1).eq."scaled") then
		print("zooming out")
		MaxLonF = -85.
		MinLatF =  21.
	end if
	LabelFontHeightF    =   0.0
	GeophysicalLineThicknessF = 1 
	domain_string = sprintf("%.1fE", MinLonF) + sprintf("%.1fE", MaxLonF) + sprintf("%.1fN", MinLatF) + sprintf("%.1fN", MaxLatF)

	k = ind(f->x .ge.MinLonF.and.f->x .le.MaxLonF.and.f->y .ge.MinLatF.and.f->y .le.MaxLatF)
 
	; cut out needed nodes for smaller file
	sm = workdir+"fort.63."+domain_string
	if(newgrid) then
		system("rm -vf "+sm+".nc") 
		g = addfile(sm+".nc","c")
		; Thin zeta, depth, x, y, and areaCell.
		g->zeta = f->zeta(:,k)
		g->depth = f->depth(k)
		g->x = f->x(k)
		g->y = f->y(k)
		a = addfile("/glade/p/work/ahijevyc/ADCIRC/duda/adcirc_Ike_tri_mesh.nc","r")
		g->areaCell = a->areaCell(k)

		; Read file that lists nodes where surface submergence state is 1
		sfc_sub_state_file = "/glade/scratch/fossell/ADCIRC/IKE_RUN/nos_grid/control/surface_submergence_state_14040.txt"
		lines = asciiread(sfc_sub_state_file, -1, "integer")
		; asciiread() reads into a 1-D array. the file is 2 columns, so read every other one, starting with element zero 
		; to get the first column. These are the inodes. 
		inodes = lines(::2)
		; Create a new variable to hold the surface submergence state.
		sfc_sub_state = new(dimsizes(f->depth), "integer")
		; Set appropriate inodes to 1
		; The sfc_sub_state_file lists node indices where indices are 1-based.  But ncl is zero-based.  So subtract one from the node indices.
		sfc_sub_state(inodes-1) = 1
		g->sfc_sub_state = sfc_sub_state(k)
		print("now you can run "+modelstr+" with newgrid=False")
	end if

	; Model time series interpolated to observation lat/lon
	g = addfile(idir+"fort.61.nc","r")
	station_time = g->time
	station_name = str_strip(tostring(g->station_name))
	istation = ind(station_name .eq. "8768094")
	station_lon = g->x(istation)
	station_lat = g->y(istation)
	station_lon = -93.3430
	station_lat =  29.7680
	station_zeta = g->zeta(:,istation)
	; model station_time is every 6 minutes (not same as f->time)
	print("interpolating model station time (every 6 min) to f->time")
	station_zetas = int2p_Wrap(station_time, station_zeta, f->time, 1)

	f = addfile(sm+".nc","r")
	outfile := workdir+modelstr+".notide"+notide+"_"+thresh_string
	print("opening "+outfile)
	wks = gsn_open_wks("png",outfile)
	timeseries_file = outfile + "."+domain_string+".timeseries.nc"
	zeta := f->zeta
	if(notide)then ; toggle to plot surge time series with astronomical tide removed.
		print("subtracting tide")
		g := addfile(idir+"../coldstart_extend/fort.61.nc","r")
		station_zeta_tide = g->zeta
		station_zeta = station_zeta - station_zeta_tide(:,istation)
		a = addfile(idir+"../coldstart_extend/fort.63.nc","r")
		zeta_nostorm = where(ismissing(a->zeta),0,a->zeta)
		zeta = zeta - zeta_nostorm(:,k)
		print("subtracted tide")
	end if

	station_obs_file = "./observations/CO-OPS__8768094__wl.csv"
	lines := asciiread(station_obs_file, -1, "string")
	delim = ","
	DateTimeObs =         str_get_field(lines,1,delim)
	WaterLevel  = tofloat(str_get_field(lines,2,delim))
	Quality     =         str_get_field(lines,8,delim)
	year  = tointeger(str_get_cols(DateTimeObs, 0, 3))
	month = tointeger(str_get_cols(DateTimeObs, 5, 6))
	day   = tointeger(str_get_cols(DateTimeObs, 8, 9))
	hour  = tointeger(str_get_cols(DateTimeObs,11,12))
	minute= tointeger(str_get_cols(DateTimeObs,14,15))
	second=minute
	second=0
	; There is a bug in cd_inv_calendar. Use ut_inv_calendar.
	; See https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=4&ved=0CDUQFjADahUKEwjzrKzsy7_IAhUW-2MKHR3FBKE&url=http%3A%2F%2Fmailman.ucar.edu%2Fpipermail%2Fncl-talk%2F2015-July%2F003428.html&usg=AFQjCNHat_z7xtV2q_LT817CbN7e6avfWQ
	station_obs_time = ut_inv_calendar(year, month, day, hour, minute, second, station_time@units, 0)
	print("interpolating observed station water level to f->time")
	station_obs = int2p_Wrap(station_obs_time, WaterLevel, f->time, 1)

	trackfile = idir+"fort.22"
	if(fileexists(trackfile))then
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
		tracktime = ut_inv_calendar(year, month, day, hour, minute, second, station_time@units, 0)
		trackheading := tofloat(str_get_field(lines, 26, delim))
		trackI := sin(trackheading/180*3.141592)
		trackJ := cos(trackheading/180*3.141592)
		vmax   := tofloat(str_get_field(lines, 9, delim))
		rad    := tofloat(str_get_field(lines, 12, delim))
	end if

	ntime = dimsizes(zeta&time)
	nnodes = dimsizes(zeta)
	nnodes := nnodes(1)
	stride=tointeger(max( (/ 1., nnodes^0.4/100 /) ))
	depth = f->depth(::stride)
	sfc_sub_state := f->sfc_sub_state(::stride)

	date_str1 = date_str(f->time)
	Re = 6371.; radius of Earth in km
	areaCell := f->areaCell(::stride) * Re^2.

	gsn_define_colormap(wks,"WhiteBlueGreenYellowRed")
	res                          = True
	res@gsnDraw                  = False
	res@gsnFrame                 = False
	res@gsnLeftStringFontHeightF = 0.012
	res@cnLevelSelectionMode     = "ManualLevels"
	res@cnMinLevelValF           =  1e-11
	res@cnMaxLevelValF           =  5.
	res@cnLevelSpacingF          =  0.5

	res@vpXF                     =  0.2
	res@vpWidthF                 =  0.6
	res@vpYF                     =  0.57
	res@vpHeightF                =  0.41

	res@sfFirstNodeIndex         = 1
	res@sfXArray                 = f->x(::stride)
	res@sfYArray                 = f->y(::stride)
	res@cnFillOn                 = True
	res@cnLinesOn                = False
	res@cnFillMode               = "RasterFill"
	res@cnLineLabelsOn           = True
	res@cnLineLabelPlacementMode = "Constant"
	res@cnLineLabelFontHeightF   = LabelFontHeightF
	res@lbLabelAutoStride        = True
	res@lbTitleString            = zeta@long_name + " (meters)"
	res@lbTitleFontHeightF       = 0.016
	res@lbTitlePosition          = "Bottom"
	res@mpDataBaseVersion        = "HighRes" ; "MediumRes" will run faster.
	res@mpLimitMode              = "LatLon"
	res@mpMinLonF                = MinLonF
	res@mpMaxLonF                = MaxLonF
	res@mpMinLatF                = MinLatF
	res@mpMaxLatF                = MaxLatF
	res@mpPerimOn                = True
	res@mpGeophysicalLineThicknessF = GeophysicalLineThicknessF
	res@pmTickMarkDisplayMode    = "Always"    ; Turn on map tickmarks.
	res@mpFillOn                 = False

 	; adding TC symbol http://www.ncl.ucar.edu/Support/talk_archives/2012/3195.html
	storm_center_res := True
	symsize := 1.2
	storm_center_res@gsMarkerIndex = NhlNewMarker(wks,"p",37,0.0,0.0,1.0,symsize,0.)

	; Time series panel
	sres                        = True
	sres@gsnFrame               = False
	sres@gsnDraw                = False
	sres@tiMainString           = modelstr + " run,  notide=" + notide
	sres@xyLineColor            = "black"
	sres@tiYAxisFontHeightF     =  0.013
	sres@xyLineThicknessF       =  3.
	sres@gsnYRefLine            =  0.0
	sres@tmXBLabelFontHeightF   =  0.015
	sres@xyLabelMode            = "Custom"
	sres@xyLineLabelFontHeightF =  0.008
	sres@vpXF                   =  0.2
	sres@vpWidthF               =  0.7
	sres@vpYF                   =  0.9
	sres@vpHeightF              =  0.15
	lres                        = True
	lres@gsLineThicknessF       =  4.

	mres                      = True
	mres@gsMarkerIndex        = "x"
	mres@gsMarkerThicknessF   = 4.
	mres@gsMarkerSizeF        = 0.01

	resTick                = True
	resTick@ttmFormat      = "%d %c"
	resTick@ttmAxis        = "XB"
	resTick@ttmValues      = (/ (/ 2008, 9,  7, 0, 0, 0 /), \
		                    (/ 2008, 9,  8, 0, 0, 0 /), \
		                    (/ 2008, 9,  9, 0, 0, 0 /), \
		                    (/ 2008, 9, 10, 0, 0, 0 /), \
		                    (/ 2008, 9, 11, 0, 0, 0 /), \
		                    (/ 2008, 9, 12, 0, 0, 0 /), \
		                    (/ 2008, 9, 13, 0, 0, 0 /), \
		                    (/ 2008, 9, 14, 0, 0, 0 /) /)
	time_axis_labels(f->time, sres, resTick)
 
	control_timeseries_file := "/glade/p/work/ahijevyc/ADCIRC/control/control.notide"+notide+"_"+thresh_string+"."+domain_string+".timeseries.nc"
	if(.not.fileexists(control_timeseries_file).and.modelstr.ne."control")then
		print("control timeseries file doesn't exist yet. make it.")
	end if
	c := addfile(control_timeseries_file,"r")

	if(fileexists(timeseries_file))then
		g := addfile(timeseries_file,"w")
		if(ismissing(g).or..not.isfilevar(g,"inundation_volume"))then
			system("rm -vf "+timeseries_file)
			print("run again now")
			exit
		end if
		inundation_volume = g->inundation_volume
		if(.not.isfilevar(g,"inundation_true"))then
			inundation_true = new((/ntime,nnodes/),byte)
			inundation_true@long_name = "1b=inundated"
			inundation_true!0="time"
			inundation_true&time = zeta&time
			inundation_true!1="node"
			g->inundation_true = inundation_true
		end if
		inundation_true = g->inundation_true
	else
		system("rm -f "+timeseries_file)
		g = addfile(timeseries_file,"c")
		inundation_volume = new(ntime,double)
		inundation_volume@long_name = "inundation volume"
		inundation_volume@_FillValue = -999.; need short number for titles (default is minus 1 zillion billion)
		inundation_volume@units = "km~S~3~N~"
		inundation_volume@height_threshold = thresh
		inundation_volume@height_threshold_units = "m"
		inundation_volume!0 = "time"
		inundation_volume&time = zeta&time

		inundation_true = new((/ntime,nnodes/),byte)
		inundation_true@long_name = "1b=inundated"
		inundation_true!0="time"
		inundation_true&time = zeta&time
		inundation_true!1="node"
	end if
	g->inundation_volume = inundation_volume
	g->inundation_true = inundation_true

	; meta data for sanity check
	txres = True
	txres@txFontHeightF = 0.01
	txres@txJust  = "BottomLeft"

; uncommment to just plot the time with maximum bulge volume
; assumes time series is complete already

	itime = maxind(inundation_volume)
	if(ismissing(itime))then
		itime=235
	end if

	do itime=itime,itime;200,ntime-1,1
		; Vertical line at current time
		sres@gsnXRefLine = f->time(itime)
		sres@gsnRightString = date_str1(itime) 
		print(date_str(f->time(itime)))

		; Get current lat/lon of storm, interpolating fort.22
		; Find first track time later than frame time, tracki
		tracki = min(ind(tracktime .ge. f->time(itime)))
		if(rad(tracki).ne.34)then
			; sanity check; tracki should correspond to a rad=34kt line and tracki-1 to a 34, 50, or 64kt line.
			print("unexpected wind intensity threshold in fort.22 file")
			exit
		end if
		; Get time interval between tracki and tracki-1 and fraction of time past by frame time
		frac = tofloat((f->time(itime) - tracktime(tracki-1)) / (tracktime(tracki)-tracktime(tracki-1)))
		tracklat0 = (1 - frac) * tracklat(tracki-1) + frac * tracklat(tracki)
		tracklon0 = (1 - frac) * tracklon(tracki-1) + frac * tracklon(tracki)
		vmax0     = (1 - frac) * vmax(tracki-1)     + frac * vmax(tracki) 
		; trackJ0 and trackI0 are vector components of heading
		trackJ0   = (1 - frac) * trackJ(tracki-1)   + frac * trackJ(tracki) + tracklat0
		trackI0   = (1 - frac) * trackI(tracki-1)   + frac * trackI(tracki) + tracklon0
		ring_km = 800.
		dist := gc_latlon(res@sfYArray,res@sfXArray,onedtond(tracklat0,dimsizes(res@sfYArray)),onedtond(tracklon0,dimsizes(res@sfXArray)),2,-4) ; accurate calculation (great-circle distance)
		if(min(dist).gt.ring_km)then
			print("storm outside domain. skipping.")
			continue
		end if
		lat :=  transpose( (/ onedtond(tracklat0,dimsizes(res@sfYArray)), onedtond(trackJ0,dimsizes(res@sfYArray)), res@sfYArray /) )
		lon :=  transpose( (/ onedtond(tracklon0,dimsizes(res@sfXArray)), onedtond(trackI0,dimsizes(res@sfXArray)), res@sfXArray /) )
		LorR := gc_dangle(lat,lon)
		dist_right = dist * -sin(LorR/180.*3.141592)
		zeta1 := zeta(itime,::stride)
		res@sfDataArray = zeta1
		map := gsn_csm_contour_map(wks,zeta1,res)

		; Dot nodes 
		ssres                  = True
		ssres@gsMarkerColor    = "pink"
		ssres@gsMarkerIndex    = 1
		ssres@gsMarkerSizeF    = 0.004
		ssres@gsMarkerOpacityF = 0.1

		; inundation is water height above MSL minus surface height above MSL (depth is negative for positive height above MSL)
		inundation = zeta1 + depth
		if(any(ismissing(zeta1)))then
			inundation(ind(ismissing(zeta1))) = 0.
		end if
		; Isolate start dry land. Mask ocean, but not low-lying land nodes below mean sea level.
		; sfc_sub_state is missing or 1. 1 is land that starts dry but is under 0 MSL. 
		inundation = mask(inundation, depth.le.0 .or. sfc_sub_state.eq.1, True)
		if(True)then ; switch from zeta to inundation
			setvalues map@data
				"sfDataArray" : inundation
			end setvalues
		end if

		; Tried to use gsn_polymarker procedure but dots would be overlaid by filled contours.
		volume = stride * areaCell * inundation/1000.
		;tmp := maxind(volume)
		;print("areaCell="+tostring(areaCell(tmp))+"sq km, inundation="+tostring(inundation(tmp))+"m, volume="+tostring(volume(tmp))+" "+tostring(res@sfXArray(tmp))+"E "+tostring(res@sfYArray(tmp))+"N")
		fract = 0.50
		right_length_km = length_scale(volume,dist_right,  fract + (1-fract)/2.)
		left_length_km  = length_scale(volume,dist_right, (1-fract)/2.)
		; used to be .and.inundation.ge.0, but we don't want dry land nodes
		bi := ind(dist_right.ge.left_length_km.and.dist_right.le.right_length_km.and.inundation.gt.0)
		if(.not.any(ismissing(bi)))then
			inundation_volume(itime) = sum(volume(bi))
			g->inundation_volume(itime) = (/ inundation_volume(itime) /)
			average_depth = sum(inundation(bi)*areaCell(bi))/ sum(areaCell(bi))
			inundation_area = sum(mask(areaCell(bi),inundation(bi).ge.thresh,True))
			; remember to reset zeroes or else you get 1's from previous runs.
			g->inundation_true(itime,:) = 0b
			g->inundation_true(itime,bi) = 1b
		end if
	
		; IKE coordinates in control run.
		icontrol := ind(c->inundation_true(maxind(c->inundation_volume),:).eq.1)
		volume_in_ctrl = sum(volume(icontrol))
		; Draw (pink) dots 
		;dots := gsn_add_polymarker(wks,map,res@sfXArray(icontrol),res@sfYArray(icontrol),ssres)



		; tried to use gsnLeftString resource but it wouldn't update the resource on the map object after I created map.
		tail_fract_str = sprintf("%0.0f",100*(1-fract)/2.)+"%" 
		gsn_text_ndc(wks,date_str1(itime) + \
			sprintf("~C~inundation volume threshold: %.0f",fract*100)+"% (" +tail_fract_str+" to the left and "+tail_fract_str+" to the right)"+\
			"~C~" + inundation_volume@long_name + sprintf(":%6.2f", inundation_volume(itime)) + inundation_volume@units + \
			" / length scale:" + sprintf("%4.0fkm",right_length_km-left_length_km) + " / average depth: " + sprintf("%.1fm",average_depth) +\
			" / inundation >= "+thresh_string+": " + sprintf("%.0fkm~S~2~N~",inundation_area) +\
			"~C~inundation volume in control surge area (pink): " + sprintf("%6.2fkm~S~3~N~",volume_in_ctrl), 0.204, 0.61, txres)

		storm_track := gsn_add_polyline(wks,map,tracklon,tracklat,lres)


		; Draw LS contours (left and right sides)
		LSres = True
		LSres@gsnDraw = False
		LSres@gsnFrame = False
		LSres@cnLevelSelectionMode = "ExplicitLevels"
		LSres@cnLevels = (/ left_length_km, right_length_km /)
		LSres@cnExplicitLineLabelsOn = True
		LSres@cnLineLabelStrings = (/ "Left: "+sprintf("%.0fkm",left_length_km), "Right: "+sprintf("%.0fkm",right_length_km) /)
		LSres@cnLineLabelInterval = 1
		LSres@sfFirstNodeIndex = res@sfFirstNodeIndex
		LSres@sfXArray = res@sfXArray
		LSres@sfYArray = res@sfYArray
		LSres@cnInfoLabelString = "length scale $CMN$ to $CMX$ km"
		;LSres@cnLevelSelectionMode = "AutomaticLevels" ; plot a bunch of contours
		LS := gsn_csm_contour(wks, dist_right, LSres)
		;overlay(map, LS)

		storm_center := gsn_add_polymarker(wks,map,tracklon0,tracklat0,storm_center_res)
		vmax_res = True
		vmax_res@txFontHeightF = 0.01 + vmax0/6000.
		vmax_res@txFontOpacityF = 0.7
		;storm_center_vmax := gsn_add_text(wks,map,sprintf("%.0fkt",vmax0),tracklon0,tracklat0,vmax_res)

		; Sanity check dot nodes in X.
		mkres          = True
		mkres@gsMarkerIndex  = 1
		mkres@gsMarkerSizeF  = 0.001
		mkres@gsMarkerColor = "deeppink1"
		near := ind(dist_right.gt.right_length_km)
		;gsn_polymarker(wks,map,res@sfXArray(near),res@sfYArray(near),mkres)
		mkres@gsMarkerColor = "seagreen1"
		near := ind(dist_right.lt.left_length_km)
		;gsn_polymarker(wks,map,res@sfXArray(near),res@sfYArray(near),mkres)

		draw(map)
		; Dot at station of interest
		sres@xyLineColor          = "dark green"
		y1 := inundation_volume
		sres@xyExplicitLabels     = "inun da tion"
		delete(map)
		; check for 2 unique values. avoid error about zero width y axis
		if (count_unique_values(y1).ge.2)then
			; Important to use := with xy_plot or memory use will grow to > 5GB.
			xy_plot := gsn_csm_xy(wks,f->time,y1,sres)
			draw(xy_plot)
			delete(xy_plot)
		else
			print(date_str(f->time(itime))+": did not find > 2 unique values for y axis")
		end if
		; meta data for sanity check
		gsn_text_ndc(wks,date_str(f->time(itime)) +\
			sprinti("~C~every %.0i nodes",stride)+\
			"~C~made " + currentdate,0.01,0.01,txres)
		frame(wks)
	end do
	
end
; multi-panel movie
;foreach f (`seq -f '%06.0f' 1 347`)
;foreach? montage -trim -geometry 80% control.tide.$f.png control.bulge.$f.png NOS.tide.$f.png NOS.bulge.$f.png $f.png
;foreach? end
;convert -adjoin ??????.png -loop 0 -delay 80 t.gif


