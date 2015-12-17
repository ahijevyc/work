;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;=============================================================================================


; Take mean of CMORPH precipitation
; Compare to output of /glade/p/work/ahijevyc/ncl/rain_season.ncl.

file_ncl = getenv("file_ncl")
if(ismissing(file_ncl))then
	file_ncl="/glade/p/work/ahijevyc/CMORPH/CMORPH_20140801-1103.nc"
end if
field = "cmorph_precip"
outfile = "/glade/p/work/ahijevyc/CMORPH/"+systemfunc("basename "+file_ncl+ " .nc")
wks = gsn_open_wks("png",outfile)

res = True
res@cnFillOn = True
res@cnLinesOn = False
res@cnFillMode = "RasterFill"
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels =  1. * (/ 0.016, 0.025, 0.04, 0.063, 0.1, 0.16, 0.25, 0.4, 0.63, 1, 1.6, 2.5, 4, 6.3, 10, 16 /)
res@gsnRightString = "mm (6 h)~S~-1~N~"
res@mpMinLatF = -60.
res@mpMaxLatF = 60. 
res@mpCenterLonF = 180.

ff = addfile(file_ncl,"r")
do itime=0,7,2
	fp := ff->$field$(itime,:,:)
	;printVarSummary(fp)
	fp2 := ff->$field$(itime+1,:,:)
	gsn_define_colormap(wks,"prcp_1")
	res@gsnCenterString = file_ncl + "~C~" + sprinti("%0.2i-", itime*3) + sprinti("%0.2i UTC", (itime+2)*3 ) + "~C~ ~C~ "
	fp := (/ fp /) + (/ fp2 /)
	copy_VarMeta(fp2, fp)
	plot = gsn_csm_contour_map(wks,fp,res)
	; this won't work for first image because the .000002 part won't be there . it only gets renamed after the 2nd frame.
	print("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+sprinti(".%0.6i.png",itime/2+1))
	system("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+sprinti(".%0.6i.png",itime/2+1))
end do
delete(ff)

; Fix first image (see above)
system("mogrify -trim -bordercolor white -border 5 +repage -type Palette -colors 255 "+outfile+".000001.png")
print("processing success "+wks@name)
