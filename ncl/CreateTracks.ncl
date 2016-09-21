; Functions to plot different symbols
; adding TC symbol http://www.ncl.ucar.edu/Support/talk_archives/2012/3195.html

undef("create_tropical_symbol")
function create_tropical_symbol(wks,lat,vmax)
begin

  fontnum = 19
  mstring = "x"
  
  if(vmax .lt. 34) then
    return(4); hollow circle
  end if

  fontnum = 35
  mstring = "m" ; NH tropical storm
  if(lat .lt. 0) then 
    mstring = "k" ; SH
  end if

  if(vmax .ge. 64) then
    fontnum = 37
    mstring = "p" ; NH hurricane
    if(lat .lt. 0) then
      mstring = "s" ; SH hurricane
    end if
  end if
  
  
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.0
  size    = 1.2
  angle   = 0.0

  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, \
                           ratio, size, angle)

  return(new_index)
end

undef("plot_tracks")
function plot_tracks(wks,plot,valid,track_files,rx,colors)
; Input
;	wks: workstation
;	plot: plot object
;	valid: valid time
;	track_files: string array with
;		paths to track files
;		assumes ATCF
;	rx: radius of storm in degrees
;	colors: string array with colors of tracks



begin

; When adding the track polylines, Make sure each variable name is unique.
; You can do this via an array of type "graphic".
; That is what the 4 commented-out lines below are for. 
; But This only works outside of a function call. 
; See http://www.ncl.ucar.edu/Document/Graphics/Interfaces/gsn_add_polymarker.shtml
; Instead use unique_string() function and the plot@$str$ attribute.
;trackdots = new(dimsizes(track_files), graphic)
;tracklines = new(dimsizes(track_files), graphic)
;storm_circles = new(dimsizes(track_files), graphic)
;storm_centers = new(dimsizes(track_files), graphic)

; sanity check
if(dimsizes(track_files).ne.dimsizes(colors))then
	print("# track files doesn't match # of colors")
	print(track_files)
	print(colors)
	exit
end if


labels = new(dimsizes(track_files), string)

do itrack=0,dimsizes(track_files)-1
	track_file = track_files(itrack)

	; Use the basename of track_files as the label.
	tmp := str_split(track_file,"/")
	labels(itrack) = tmp(dimsizes(tmp)-1)

	adeck := read_atcf(track_file)
	i := ind(adeck@valid .eq. valid .and. adeck@rad .eq. 34)
	if (dimsizes(i).ne.1.or.ismissing(i))then
		print("no valid time "+valid+" in "+track_file)
		print(adeck@valid)
		exit
	end if
	lon0 := adeck@lon(i)
	lat0 := adeck@lat(i)
	circlat = new(100,float)
	circlon = new(100,float)
	nggcog(lat0,lon0,rx,circlat,circlon)

	pmres := True
	pmres@gsMarkerIndex = 16
	pmres@gsMarkerSizeF = 0.008
	lnres := True
	lnres@gsLineThicknessF = 3.
	cres := True
	cres@gsLineThicknessF = 3.5
	storm_center_res := True
	storm_center_res@gsMarkerIndex = create_tropical_symbol(wks,lat0,64.)
	storm_center_res@gsMarkerSizeF = 17.
	storm_center_res@gsMarkerThicknessF = 6.
	if(itrack.eq.1)then
	end if

	pmres = True
	pmres@gsMarkerIndex = 16
	pmres@gsMarkerSizeF = 0.008
	pmres@gsMarkerColor = colors(itrack)
	str = unique_string("polymarker") 
	plot@$str$ = gsn_add_polymarker(wks,plot,adeck@lon,adeck@lat,pmres)

	lnres = True
	lnres@gsLineThicknessF = 3.
	lnres@gsLineColor   = colors(itrack)
	str = unique_string("polyline") 
	plot@$str$ = gsn_add_polyline(wks,plot,adeck@lon,adeck@lat,lnres)

	cres = True
	cres@gsLineThicknessF = 3.5
	cres@gsLineColor    = colors(itrack)
	str = unique_string("polyline") 
	plot@$str$ = gsn_add_polyline(wks,plot,circlon,circlat,cres) ; removed storm within this circle

	storm_center_res := True
	storm_center_res@gsMarkerIndex = create_tropical_symbol(wks,lat0,64.)
	storm_center_res@gsMarkerSizeF = 17.
	storm_center_res@gsMarkerThicknessF = 6.
	storm_center_res@gsMarkerColor = colors(itrack)
	str = unique_string("polymarker") 
	plot@$str$ = gsn_add_polymarker(wks,plot,lon0,lat0,storm_center_res)

end do

;***********************************************
; legend resources
;***********************************************
lgres                    = True
lgres@lgLineColors       = colors
lgres@lgMonoMarkerIndex  = True
lgres@lgMarkerIndex   = pmres@gsMarkerIndex
lgres@lgMarkerSizeF   = pmres@gsMarkerSizeF
lgres@lgMarkerColors = colors
lgres@lgLineThicknessF   = lnres@gsLineThicknessF
lgres@lgLabelFontHeightF = 0.15
lgres@lgItemType         = "MarkLines"
lgres@vpWidthF           = 0.21           ; width of legend (NDC)
lgres@vpHeightF          = 0.1            ; height of legend (NDC)
lbid = gsn_create_legend(wks,dimsizes(track_files),labels,lgres)         ; create legend


amres = True
amres@amParallelPosF   = 0.74		    ; move legend to the right
amres@amOrthogonalPosF = -0.4             ; move the legend up
annoid1 = gsn_add_annotation(plot,lbid,amres)   ; add legend to plot





return(0)



end
