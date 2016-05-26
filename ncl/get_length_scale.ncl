undef("get_length_scale")
function get_length_scale(volume:numeric,dist:numeric,thresh:numeric)
begin
	txres = True
	txres@txFontHeightF = 0.01
	txres@txJust = "BottomLeft"

	; 1000 points denoting 999 evenly spaced bins
	xs = fspan(min(dist), max(dist), 1000)
	xs@long_name = "distance to right edge of bin (km)"
	dbin = xs(1)-xs(0)

	ivol = new(dimsizes(xs), double)
	ivol@long_name = "volume in "+sprintf("%2.0f-km",dbin)+" distance bin~C~km~S~3~N~"

	do i=1,dimsizes(ivol)-1
		ivol(i) = sum(mask(volume, dist.ge.xs(i-1) .and. dist.lt.xs(i), True))
	end do

	if(max(volume).eq.0)then
		print("get_length_scale: no inundation")
		return(default_fillvalue("double"))
	end if
	
	if(max(cumsum(ivol,2)).eq.0)then
		print("problem with volume")
		printMinMax(dist,False)
		printMinMax(volume,False)
	end if
	;print(ivol)
	;printMinMax(volume,0)
	;print(sum(volume))
	;print(max(cumsum(ivol,2)))
	
	norms = cumsum(ivol,2)/sum(volume)
	norms@long_name = "normalized cumulative"
	; Get first non-zero bin for which the cumulative normalized norms >= thresh
	iexceed := min(ind(norms.ge.thresh.and.norms.gt.0)) ; thresh exceeded somewhere in bin iexceed
	fract   := (thresh - norms(iexceed-1))/(norms(iexceed)-norms(iexceed-1))
	length  := xs(iexceed-1) + fract*dbin ; interpolate (better than assuming center of bin)
	xyres := True
	xyres@gsnFrame = False
	xyres@trXMinF = -500
	xyres@trXMaxF = 800
	xyres@xyLineThicknessF = 2.0
	xyres@tmXMajorGrid = True
	xyres@tmXBOn = True
	xyres@tmXMajorGridLineDashPattern = 1
	y2res := xyres
	y2res@tmYMajorGrid = True
	y2res@tmYMajorGridLineDashPattern = 1
	y2res@xyLineColor = "blue"
	y2res@gsnXRefLine      = length
	y2res@gsnXRefLineColor = "red"
	y2res@gsnXRefLineThicknessF = xyres@xyLineThicknessF*2.
	if(False)then
		wks = gsn_open_wks("x11","test")
		plot  = gsn_csm_xy2(wks,xs,ivol,norms,xyres,y2res)        ; create plot
		gsn_text_ndc(wks, sprintf("%4.1f",100*thresh)+"% of volume within "+sprintf("%4.0fkm",length),0.01,0.01,txres)
		frame(wks)
	end if
	return(length)
end
