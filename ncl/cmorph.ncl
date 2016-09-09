;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/mpasrt/rt2015/ncl/get_field_res.ncl"
;=============================================================================================


; Take mean of CMORPH precipitation
; Compare to output of /glade/p/work/ahijevyc/ncl/rain_season.ncl.

if(.not.isvar("file_ncl"))then
	file_ncl="/glade/p/work/ahijevyc/CMORPH/CMORPH_20140801-1103.nc"
	file_ncl="/glade/p/rda/data/ds502.1/cmorph_v0.x/0.25deg_3hly/netcdf/2015/CMORPH_V0.x_0.25deg-3HLY_20150930.nc"
end if
if(.not.isvar("dh"))then
	dh = 6 ; number of hours to accumulate (must be multiple of 3)
end if
if(mod(dh,3).ne.0)then
	print("# of hours to accum must be mult of 3")
	print(dh)
	exit
end if
field = "cmorph_precip"
outfile = "/glade/p/work/ahijevyc/CMORPH/"+systemfunc("basename "+file_ncl+ " .nc")
wks = gsn_open_wks("png",outfile)

inches = True

res = True
res@cnFillOn = True
res@cnLinesOn = False
res@cnFillMode = "RasterFill"
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels =  10. * (/ 0.016, 0.025, 0.04, 0.063, 0.1, 0.16, 0.25, 0.4, 0.63, 1, 1.6, 2.5, 4, 6.3, 10, 16 /)
res = set_res_mp(res,"ep")
res@mpMinLatF =  10.
res@mpMaxLatF =  50.
res@mpMinLonF=-100.
res@mpMaxLonF=-30.

ff = addfile(file_ncl,"r")
do itime=0,7,dh/3
	fp := ff->$field$(itime:itime+(dh/3-1),:,:)
	if(fp@units.ne."mm (3 hr)^-1")then
		exit
	end if
	fp@units = "mm"
	fp@long_name = fp@long_name + " in past "+sprintf("%.0f",dh)+" hours"
	fp := dim_sum_n_Wrap(fp, 0)
	gsn_define_colormap(wks,"prcp_1")
	res@gsnCenterString = str_get_cols(file_ncl,-64,-1) + "~C~" + sprinti("%0.2i-", itime*3) + sprinti("%0.2i UTC", (itime+dh/3)*3 ) + "~C~ ~C~ "
	if(inches)then ; special thing to match Wei's plots of Joaquin
		res@cnLevels :=  (/ 0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5 /)
		gsn_define_colormap(wks,"WhBlGrYeRe")
		fp = fp * 0.0393701 ; mm to inches
		fp@units = "in"
	end if
	plot = gsn_csm_contour_map(wks,fp,res)
	; this won't work for first image because the .000002 part won't be there . it only gets renamed after the 2nd frame.
	print("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+sprinti(".%0.6i.png",itime/2+1))
	system("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+sprinti(".%0.6i.png",itime/2+1))
end do
delete(ff)

; Fix first image (see above)
system("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+".000001.png")
print("processing success "+wks@name)

