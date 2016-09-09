;*************************************************
; wind_3.ncl
;*************************************************
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"   
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
;*************************************************
begin
	;*************************************************
	; open file and read in data
	;*************************************************
	ifile = "/glade/scratch/weiwang/v371/WRFV3/jq/test1_modtk/wrfout_d01_2015-10-02_03:00:00"
	f    = addfile (ifile, "r")

	; Get top and bottom pressure levels.
	;
	; stole from steering.ncl Aug 1 2016
	ifhr=0
	if(.not.isvar("pbot")) then
		pbot = 300.
	end if
	if(.not.isvar("ptop")) then
		ptop = 200.
	end if
	layerstr = sprintf("%.0f",pbot)+"-"+sprintf("%.0f",ptop)+"hPa"
	if(isfilevar(f,"PRES"))then
		p = wrf_user_getvar(f,"PRES",ifhr)
	else
		p = wrf_user_getvar(f,"p",ifhr)
	end if
	zbot = -1
	tmp := dimsizes(p)
	do z=0,tmp(0)-1 
		a = avg(p(z,:,:))
		if(zbot.eq.-1.and.a.lt.pbot*100)then
			zbot = z
		end if
		if(a.gt.ptop*100)then
			ztop = z
		end if
	end do

	times = wrf_user_list_times(f)
	uvm = wrf_user_getvar(f,"uvmet",ifhr)
	u = uvm(0,zbot:ztop,:,:)
	v = uvm(1,zbot:ztop,:,:)
	desc = "averaged between vertical levels "+tostring(zbot)+" and "+tostring(ztop)
	
	u := dim_avg_n_Wrap(u,0)
	v := dim_avg_n_Wrap(v,0)


	;*************************************************
	; calculate total wind speed
	;*************************************************
	spd = sqrt(u^2+v^2)
	spd@description = layerstr + " wind speed (filled contours; m/s) "+desc

	;*************************************************
	; calculate divergence 
	;*************************************************
	div = uv2dvF_Wrap(u,v)                ; u,v ==> divergence

	;*************************************************
	; calculate velocity potential 
	;*************************************************
	chi = ilapsF_Wrap ( div , 0)
	chi = (/chi/1e6/)                     ; arbitrary scale
	chi@long_name = "velocity potential"
	chi@units     = "m/s" 
	;*************************************************
	; calculate divergent wind component 
	;*************************************************    
	tmp  := new (array_append_record(2, dimsizes(div),0), typeof(div), div@_FillValue )
	tmp = dv2uvF_Wrap(div) ; div  ==> divergent  wind components
	ud = tmp(0,:,:)
	vd = tmp(1,:,:)
	ud@description = ud@long_name ; wrf_vector uses description attribute, but long_name is better.
	ud@description = "divergent wind vectors"
	;*************************************************
	; plot results
	;*************************************************    
	wks  = gsn_open_wks("png","wind")              ; open a workstation

	resc = True
	resc@cnFillOn = True
	gsn_define_colormap(wks,"matlab_hot")
	gsn_reverse_colormap(wks)
	; Change opacity
	opacity = 0.86
	tmp := gsn_retrieve_colormap(wks)
	nc = dimsizes(tmp)
	nc := nc(0)
	colors = new((/nc,4/),typeof(tmp))
	colors(:,0:2) = tmp
	colors(:,3) = opacity
	resc@cnFillPalette = colors
	resc@gsnSpreadColorEnd=58
	resc@cnLevelSelectionMode = "ManualLevels"
	resc@cnMinLevelValF = 20.
	resc@cnMaxLevelValF = 60.
	resc@cnLevelSpacingF =10.
	contour_c = wrf_contour(f, wks, spd, resc)

	res                       = True
	res@vcRefMagnitudeF       =  5.                ; make vectors larger
	res@vcMinMagnitudeF       =  5.
	res@vcRefLengthF          = 0.02               ; ref vector length
	res@vcMinDistanceF        = 0.037                ; thin the vectors
	res@vcRefAnnoOrthogonalPosF  = 0.02          ; Move ref anno into plot
	res@vcGlyphStyle          = "LineArrow"
	res@vcLineArrowThicknessF = 4.
	res@vcRefAnnoOn           = True
	res@TimeLabel             = times(ifhr)
	res@MainTitle             = str_get_cols(ifile,14,-1)

	vector=wrf_vector(f, wks, ud, vd, res)

	mres        = True
	mres@ZoomIn = True
	mres@Xstart =   48
	mres@Xend   =  800
	mres@Ystart =   39
	mres@Yend   =  395
	mres@mpGeophysicalLineThicknessF = 1.
	mres@mpGeophysicalLineColor = "Black"

	pres = True
	over_id = wrf_map_overlays(f, wks, (/contour_c, vector /), pres, mres)
end

