;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;=============================================================================================

begin
if(.not.isvar("mesh")) then 
  mesh = "us"
end if
nsmooth = 500

diri = "/glade/scratch/mpasrt/"+mesh+"/2016102700/"
output_file = "./areaCell_"+mesh
wks_type = "png"
wks_type@wkWidth=2500
wks_type@wkHeight=2500
wks = gsn_open_wks(wks_type,output_file)
gsn_define_colormap(wks,"sunshine_9lev")
gsn_reverse_colormap(wks)
;SET RESOURCES:
res = True
res@gsnLeftString = "diameter of circle~C~with same area as cell"
res@gsnCenterString = mesh
res@gsnRightString = sprinti("%i ", nsmooth) + "smoothing passes"
res@cnFillOn = True
res@cnLinesOn = True
res@cnLevelSelectionMode = "ExplicitLevels"
res@cnLevels = (/16,24,32,40,48/)
res@cnLevels := (/15,20,25,30,35,40,45,50,55,60,65/)
;res@cnLevels := (/20,30,40,50,60/)
res@cnFillOpacityF = 0.7
res@cnLineLabelInterval = 1
res@mpLimitMode = "MaximalArea"
res@mpGeophysicalLineThicknessF = 2.

res@mpProjection = "Satellite"
;res@mpProjection = "CylindricalEquidistant"
res@mpSatelliteDistF = 100000000.
res@mpCenterLatF = 35.

res@mpCenterLonF = -100.
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
pi = atan(1)*4.0d
r2d = 180.0d/pi ; conversion from radians to degrees. 
init_ncl = diri+"init.nc"
init = addfile(init_ncl,"r")
res@sfXArray = init->lonCell * r2d
res@sfYArray = init->latCell * r2d
nEdgesOnCell = init->nEdgesOnCell
cellsOnCell = init->cellsOnCell
verticesOnCell = init->verticesOnCell
dv = dimsizes(verticesOnCell)
nCells = dv(0)
maxEdges = dv(1)
itime = 0
fp = todouble(init->areaCell)
mpas_filter_cells(nEdgesOnCell, cellsOnCell, maxEdges, nCells, fp, nsmooth)

plot = gsn_csm_contour_map(wks,sqrt(fp/pi)*2/1000,res)

delete(fp)
print("processing success "+wks@name)
end

;=============================================================================================
