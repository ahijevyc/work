;=============================================================================================
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
;=============================================================================================

begin
if(.not.isvar("field")) then 
 field = "REFD_MAX"
end if
if(.not.isvar("subdir")) then 
 subdir = "ens_1"
end if

if(.not.isvar("file_ncl")) then 
	file_ncl = "/glade/scratch/ahijevyc/trier/"+subdir+"/diags_d02.2015-06-05_00:00:00.nc"
end if
diri = systemfunc("dirname "+file_ncl)+"/"
cmd = "basename "+file_ncl+" nc"
;print(cmd)
output_file = diri+systemfunc(cmd)+field+".png"
print("output file: "+output_file)
if(fileexists(output_file))then
    print("output file "+output_file+" exists. Skipping")
    exit
end if
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
res@cnMaxLevelValF  = 80. 
res@cnLevelSpacingF =  5.
if(max(fp).lt.20.)then
	res@cnMinLevelValF  =  1.
	res@cnMaxLevelValF  = 16. 
	res@cnLevelSpacingF =  1.
end if

res@tiMainString = subdir
mpres=True
mpres@mpDataBaseVersion = "MediumRes"
mpres@mpOutlineBoundarySets="AllBoundaries"
mpres@mpUSStateLineThicknessF=2.0
mpres@mpGeophysicalLineThicknessF=1.75
mpres@mpCountyLineColor="gray70"
mpres@mpCountyLineThicknessF=0.5

printMinMax(fp,False)
contour = wrf_contour(ff,wks,fp(0,:,:),res)
plot = wrf_map_overlays(ff,wks,(/contour/),True,mpres)

print("processing success "+output_file)
end

;=============================================================================================
