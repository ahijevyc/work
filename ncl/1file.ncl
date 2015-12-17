;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
;=============================================================================================

begin
if(.not.isvar("date")) then
 date = "2014080100"
end if

if(.not.isvar("field")) then 
 field = "mslp"
end if
if(.not.isvar("mesh")) then 
 mesh = "mpas"
end if
diri = "/glade/p/nmmm0031/"+mesh+"/"+date+"/"
if(.not.isvar("file_ncl")) then 
	file_ncl = diri + "diagnostics.2014-08-02_00.00.00.nc"
end if
;file_ncl = "/glade/p/work/ahijevyc/rmse_comparisons/"+mesh+"/" + "w_850hPa_avgsqr_2014.nc"
output_file = diri+field
wks = gsn_open_wks("png",output_file)

;SET RESOURCES:
res = True
res@gsnDraw   = False
res@gsnFrame  = False
;res@gsnLeftString = "850hPa vertical velocity"
;res@gsnRightString = "[m/s]"
res@cnFillOn = True
res@cnLinesOn = False
res@cnFillMode = "RasterFill"
res@cnLevelSelectionMode = "ExplicitLevels"
;res@cnLevels = 100 * (/-.5,-.2,-.1,-.05,-0.02,-0.01,0,0.01,0.02,0.05,0.1,0.2,0.5/)
res@cnLevels = (/12000,12060,12120,12180,12240,12300,12360,12420,12480,12540,12600./)
res@mpLimitMode = "Corners"
res@mpLeftCornerLatF = 7
res@mpLeftCornerLonF = 130
res@mpRightCornerLatF = 23
res@mpRightCornerLonF = 145

sres = True
sres@gsnDraw   = False
sres@gsnFrame  = False
sres@cnFillOn  = False
sres@cnLinesOn = True
sres@cnLineLabelsOn = True
sres@cnLineThicknessF = 1.01
sres@cnLineLabelFontHeightF = 0.009
sres@cnInfoLabelFontHeightF = 0.01
sres@cnLineLabelPlacementMode = "Computed"

sres@cnLevelSelectionMode = "ManualLevels"
sres@cnMinLevelValF  = 900.
sres@cnMaxLevelValF  = 1030.
sres@cnLevelSpacingF =  4. 
;sres@gsnLeftString = "mean sea level pressure"
;sres@gsnRightString = "[hPa]"

r2d = 180.0d/(atan(1)*4.0d) ; conversion from radians to degrees. 
init_ncl = diri+"init.nc"
init = addfile(init_ncl,"r")
res@sfXArray = init->lonCell * r2d
res@sfYArray = init->latCell * r2d
sres@sfXArray = init->lonCell * r2d
sres@sfYArray = init->latCell * r2d
nEdgesOnCell = init->nEdgesOnCell
cellsOnCell = init->cellsOnCell
verticesOnCell = init->verticesOnCell
dv = dimsizes(verticesOnCell)
nCells = dv(0)
maxEdges = dv(1)
delete(init)
itime = 0

ff = addfile(file_ncl,"r")
res@tiMainString    = file_ncl
fp = ff->$field$(itime,:)
;fp = sqrt(ff->$field$(2,itime,:))*100.
if (field .eq. "skintemp" .or. field .eq. "t2m" .or. field .eq. "sst") then
   fp = fp-273.15
end if
printVarSummary(fp)
plot = gsn_csm_contour_map(wks,fp,res)
slp = ff->mslp(itime,:)/100
delete(ff)
plot_ov = gsn_csm_contour(wks,slp,sres)
overlay(plot,plot_ov)

draw(plot)
frame(wks)

delete(fp)
print("processing success "+output_file+".png")
end

;=============================================================================================
