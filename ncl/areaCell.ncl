;=============================================================================================
load "/glade/work/ahijevyc/ncl/get_field_res.ncl"
;=============================================================================================

begin
if(.not.isvar("mesh")) then 
  mesh = "hwt2017"
end if
nsmooth = 100

diri = "/glade/work/ahijevyc/mpas_plots/"+mesh+"/"
ofile = diri+"areaCell_"+mesh
wks_type = "png"
wks_type@wkWidth=1000
wks_type@wkHeight=1000
wks = gsn_open_wks(wks_type,ofile)
gsn_define_colormap(wks,"sunshine_9lev")
gsn_reverse_colormap(wks)
;SET RESOURCES:
res = True
res@gsnCenterString = mesh
res@nSmoothPasses = nsmooth
res@cnFillOn = True
res@cnLinesOn = True
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels = (/16,24,32,40,48,56,64/)
if(mesh.eq."mpas50_3")then
    res@cnLevels := (/2,4,8,16,32,48,64/)
end if
if(mesh.eq."hwt2017")then
    res@cnLevels := (/3,5,7,11,13,15,17/)
end if
res@cnFillOpacityF = 0.7
res@cnLineLabelInterval = 1
; Call set_res_mp so we get mpCenterLonF and mpCenterLatF
res = set_res_mp(res, mesh)
res@mpLimitMode = "MaximalArea"
res@mpGeophysicalLineThicknessF = 2.
res@mpLabelsOn = True

res@mpProjection = "Satellite"
;res@mpProjection = "CylindricalEquidistant"
res@mpSatelliteDistF = 100000000.

res@mpGridAndLimbOn = True
res@mpPerimOn = True
res@pmTickMarkDisplayMode = "Always"
res@cnLineLabelsOn = True
res@cnLineThicknessF = 1.5
res@cnLineLabelFontHeightF = 0.009
res@cnInfoLabelFontHeightF = 0.01
res@cnLineLabelPlacementMode = "Constant"
res@lbTitleOn = True
res@lbTitleString = "km"
res@lbTitleFontHeightF = 0.012
res@lbTitlePosition = "bottom"

init_ncl = diri+"init.nc"
init = addfile(init_ncl,"r")
pi = atan(1)*4.0d
fp = init->areaCell
fp = tofloat(2*sqrt(fp/pi/1000/1000))
fp@name = "cell spacing"
;fp@long_name = "circle diameter with~C~same area~C~as cells"
fp@long_name = "Cell spacing"
fp@units = "km"
res = set_res_sf(res, init, fp, 1)

plot = gsn_csm_contour_map(wks,fp,res)

timestamp = systemfunc("date '+%b %d %Y %T %Z'")
cmd = "mogrify -trim -bordercolor white -border 5 +repage -type Palette -gravity Southwest -pointsize 9 -annotate +0+0 'created "+timestamp+"' -colors 255 "+ofile+"."+wks_type
print(cmd)
system(cmd)

print("processing success "+wks@name)
end

;=============================================================================================
