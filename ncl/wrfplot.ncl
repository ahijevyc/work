;=============================================================================================
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
;=============================================================================================

begin
if(.not.isvar("date")) then
 date = "ens_10"
end if

if(.not.isvar("field")) then 
 field = "PMM"
end if
if(.not.isvar("mesh")) then 
 mesh = "RYAN_PECAN_4-5_JUNE"
end if

file_ncl = getenv("file_ncl")
if(.not.isvar("file_ncl")) then 
	file_ncl = "/glade/scratch/ahijevyc/trier/"+mesh+"/"+date+"/diags_d02.2015-06-05_00:00:00.nc"
end if
diri = systemfunc("dirname "+file_ncl)+"/"
output_file = diri+systemfunc("basename "+file_ncl+" nc")+field
print("output file: "+output_file)
wks = gsn_open_wks("png",output_file)

;SET RESOURCES:
print("opening "+file_ncl)
ff = addfile(file_ncl,"r")
fp = ff->$field$
res = True
res@TimeLabel = ff->Times
res@cnFillOn = True
gsn_define_colormap(wks,"prcp_1")
res@cnLevelSelectionMode = "ManualLevels"
res@cnMinLevelValF  =  5.
res@cnMaxLevelValF  = 75. 
res@cnLevelSpacingF =  5.
if(max(fp).lt.20.)then
	res@cnMinLevelValF  =  1.
	res@cnMaxLevelValF  = 15. 
	res@cnLevelSpacingF =  1.
end if

res@tiMainString = date
mpres=True
mpres@mpDataBaseVersion = "MediumRes"
mpres@mpOutlineBoundarySets="AllBoundaries"
mpres@mpUSStateLineThicknessF=1.25
mpres@mpGeophysicalLineThicknessF=1.75
mpres@mpCountyLineColor="gray70"
mpres@mpCountyLineThicknessF=0.5

printMinMax(fp,False)
contour = wrf_contour(ff,wks,fp(0,:,:),res)
plot = wrf_map_overlays(ff,wks,(/contour/),True,mpres)

print("processing success "+output_file+".png")
end

;=============================================================================================
