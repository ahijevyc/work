;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
;load "./gsn_csm.ncl"
;=============================================================================================

; TEMPLATE TO PLOT A MAP OF THE PRECIPITABLE WATER.

begin
wks = gsn_open_wks("ncgm","/glade/scratch/$USER/mpas2/"+date+"/d_dt_pcpw_al_"+date)

;SET RESOURCES:
res = True
res@gsnDraw             = True
res@gsnFrame            = True
res@gsnMaximize         = False
res@gsnSpreadColors     = True

res@mpProjection        = "CylindricalEquidistant"
res@mpDataBaseVersion   = "MediumRes" 
res@mpCenterLatF        = 0.
res@mpCenterLonF        = 0.

res@cnFillMode    = "AreaFill"
res@cnFillOn      = True
res@cnLinesOn     = False
res@cnInfoLabelOn = False

load "/glade/p/work/ahijevyc/res_mp_al.ncl" 

dird = "/glade/scratch/$USER/mpas2/"+date+"/"
diri = "/glade/scratch/$USER/mpas2/"+date+"/"
file_ncl = "init.nc"
ff = addfile(diri+file_ncl,"r")
;print(file_ncl)

stride = 5
r2d = 180.0d/(atan(1)*4.0d) ; conversion from radians to degrees. 
res@sfXArray = ff->lonCell(0::stride) * r2d
res@sfYArray = ff->latCell(0::stride) * r2d
delete(ff)

box = new(dimsizes(res@sfXArray),logical,False)
do i=0,dimsizes(res@sfXArray)-1 

  if (res@sfXArray(i) .ge. 360+mask_west .and. res@sfXArray(i) .lt. 360+mask_east  .and. res@sfYArray(i) .ge. mask_south .and. res@sfYArray(i) .lt. mask_north) then
      box(i) = True
  end if 
end do

gsn_define_colormap(wks,"precip_diff_12lev")


res@cnLevelSelectionMode = "ManualLevels"
res@cnMinLevelValF  = -6.
res@cnMaxLevelValF  =  6.
res@cnLevelSpacingF = 1. 
res@gsnLeftString   = "PRECIPITABLE WATER"
res@gsnRightString  = "[kg m~S~-2~N~]"

files = systemfunc (" ls -1 " + dird + "diagnost*.nc")
;files = systemfunc (" ls -1 " + "mpas.output* ")
nfiles = dimsizes(files)
if (nfiles .lt. 1)
   print("only "+nfiles+" found. need at least 1. Can ignore first one because its 0h diag with zero precipw")
   exit
end if

; df is number of files to advance. If they are hourly, then dt is 1h. If daily, dt is 1day.
df = 1
;loop over the number of files:
do nf = df, nfiles-1 
   fhour = nf
   t1 = addfile(files(nf-df),"r")
   t2 = addfile(files(nf),"r")
   iTime = 0
   xtime1 = chartostring(t1->xtime(iTime,0:12))
   print("processing file "+files(nf)+" and "+files(nf-df))
   xtime2 = chartostring(t2->xtime(iTime,0:12))
   res@tiMainString = "MPAS VAR RES FCST VALID AT "+xtime2+" - FCST VALID AT "+xtime1
   precipw = t2->precipw(iTime,0::stride)- t1->precipw(iTime,0::stride)
   precipw = mask(precipw,box,True)
   plot = gsn_csm_contour_map(wks,precipw,res)
   delete(plot)

end do

   print("processing success "+wks@name)

end

;=============================================================================================
