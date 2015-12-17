undef("length_scale")
function length_scale(volume:numeric,dist:numeric,fract:numeric)
begin
	txres = True
	txres@txFontHeightF = 0.01
	txres@txJust = "BottomLeft"
	dbin = 4
	dmax = 800
	ivol = new(round(2*dmax/dbin,3),double)
	xs := ivol
	xs@long_name = "distance (km)"
	ivol@long_name = "volume per "+sprintf("%2.0f-km",dbin)+" distance bin~C~km~S~3~N~"
	do i=0,dimsizes(ivol)-1
		xs(i) = -dmax + i*dbin + dbin/2.
		ivol(i) = sum(mask(volume,dist.ge.(xs(i)-dbin/2).and.dist.lt.(xs(i)+dbin/2),True))
	end do
	norms = cumsum(ivol,2)/max(cumsum(ivol,2))
	norms@long_name = "normalized cumulative"
	length := xs(min(ind(norms.ge.fract))) ; fract exceeded somewhere in bin, assume center.
	xyres := True
	xyres@gsnFrame = False
	xyres@trXMinF = -dmax
	xyres@trXMaxF = dmax
	xyres@xyLineThicknessF = 2.0
	xyres@tmXMajorGrid = True
	xyres@tmXBOn = True
	xyres@tmXMajorGridLineDashPattern = 1
	y2res := xyres
	y2res@tmYMajorGrid = True
	y2res@tmYMajorGridLineDashPattern = 1
	y2res@xyLineColor = "blue"
	y2res@gsnXRefLine = length
	y2res@gsnXRefLineThicknessF = xyres@xyLineThicknessF*2.
	;wks = gsn_open_wks("x11","test")
	;plot  = gsn_csm_xy2(wks,xs,ivol,norms,xyres,y2res)        ; create plot
	;gsn_text_ndc(wks, sprintf("%4.1f",100*fract)+"% of volume within "+sprintf("%4.0fkm",length),0.01,0.01,txres)
	;frame(wks)
	return(length)
end
