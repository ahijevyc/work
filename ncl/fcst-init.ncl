;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
;=============================================================================================

begin

; this NCL script run by ~ahijevyc/bin/run_fcst-init.sh 
;
; Set default values if not provided on command line. For example, ncl "date=2013091500" 'mpas="mpas"' 'fieldname="q2"' . 
if(.not.isvar("workdir")) then
   workdir="/glade/scratch/ahijevyc/"
end if
if(.not.isvar("mpas")) then
   mpas="mpas"
end if
if(.not.isvar("fieldname")) then
   fieldname="precipw"
end if
if(.not.isvar("date")) then
   date="2013091400"
end if

; hard-wired to ahijevyc for post-post-processing. Could be $USER
outdir = workdir+mpas+"/"+date+"/"

syear = str_get_cols(date,0,3)
smonth = str_get_cols(date,4,5)
sday= str_get_cols(date,6,7)
shour= str_get_cols(date,8,9)
iyear = toint(syear)
imonth = toint(smonth)
iday= toint(sday)
ihour= toint(shour)
xtime2 = syear + "-" + smonth + "-" + sday + "_" + shour

; find forecasts with requested valid time. Make sure date dir ends with digit (ignore *_new).
dird = workdir+mpas+"/201[0-9][01][0-9][0123][0-9][0-9][0-9]/"
files = systemfunc (" ls -1 " + dird + "diag*."+xtime2+".00.00.nc")
nfiles = dimsizes(files)
if (nfiles .lt. 1) then
   print("No forecast "+dird+"diag*."+xtime2+".00.00.nc files found. need at least 1.")
   exit
end if
init_file = files(nfiles-1)
; make sure last item in list of forecasts is the 0-h forecast, in other words, it is in the requested date directory.
if(ismissing(str_index_of_substr(init_file,"/"+date,0))) then
  print("looked for /"+date+". No t=0 file found in "+init_file)
  exit
end if

ff = addfile(init_file,"r")
field_init = ff->$fieldname$

ncfile = outdir+fieldname+"_f-i.nc"
if (isfilepresent(ncfile)) then 
   system("rm -v "+ncfile)
end if

ncdf = addfile(ncfile, "c")

nl = integertochar(10) ; newline character
globalAtt = True
globalAtt@history = nl+\
  systemfunc("date")+": ncl fcst-init.ncl"
globalAtt@date = date
globalAtt@mpas = mpas
globalAtt@fieldname=fieldname
globalAtt@workdir=workdir
globalAtt@init_file=init_file
globalAtt@fcst_files=files(0:nfiles-1)
fileattdef( ncdf, globalAtt )


; used to start at 1d to save space, but this complicated mpas_basin_rmse.pro
lead_times = (/ 0d, 1d, 2d, 3d, 4d, 5d, 6d, 7d, 8d, 9d, 10d /)
dsizes = dimsizes(field_init)
if (mpas.eq."GFS".or.mpas.eq."GFS_00Z") then ; maybe I could copy dim coord from mpas too.
  ; copy dimension coordinates (vert, lat, lon) to output file
  ; some fields have no vertical dimension
  do idim = 0, dimsizes(dsizes)-1
    ncdf->$field_init!idim$ = ff->$field_init!idim$
  end do
  delete(lead_times) ; shorten from 10 to 8 days for GFS and do every 6 hours
  lead_times = fspan(0.d, 8d, 33)
end if

filedimdef(ncdf,"lead_time",-1,True)
lead_times@long_name = "lead time"
lead_times@units = "days"
nfile = new( (/ dimsizes(lead_times) /), typeof(lead_times))
nfile = 0
nfile!0 = "lead_time"
nfile&lead_time = lead_times
; Used to be used primarily on MPAS diag files.
; Used to remove initial Time dimension
; Not sure how to accommodate different number of dimensions without
; adding more if clauses.
; Luckily, even though the MPAS diag fields are essentially 1-D (nCells), 
; they have the degenerate Time dimension, which makes them 2-D, just 
; like the GFS fields (lon, lat). 
if (dimsizes(dsizes).eq.2) then
   diff = new( (/ dimsizes(lead_times), dsizes(0), dsizes(1) /),typeof(field_init))
end if
if (dimsizes(dsizes).eq.3) then
  diff = new( (/ dimsizes(lead_times), dsizes(0), dsizes(1), dsizes(2) /),typeof(field_init))
end if
diff!0 = "lead_time"
diff&lead_time = lead_times
diff@long_name = "difference field for "+fieldname

; assign dimension names from field_init to diff field
; tried to do this in do loop below but it didn't work:
; it came up with cruddy dimension names like ncl_0 anc ncl_1, etc.
do idim = 0, dimsizes(dsizes)-1 
  diff!(idim+1) = field_init!idim
end do

sqdiff = diff
sqdiff@long_name = "squared " + diff@long_name

;loop over forecasts with requested valid time
do nf = 0, nfiles-1, 1
   idate = str_index_of_substr(files(nf), "201", 1)
   fyear  = toint(str_get_cols(files(nf), idate  ,idate+3))
   fmonth = toint(str_get_cols(files(nf), idate+4,idate+5))
   fday   = toint(str_get_cols(files(nf), idate+6,idate+7))
   fhour  = toint(str_get_cols(files(nf), idate+8,idate+9))
   lead_time = greg2jul(iyear,imonth,iday,ihour) - greg2jul(fyear,fmonth,fday,fhour)
    ; populate correct index of lead_time dimension
   ilead_time = ind(lead_times.eq.lead_time)
   if (ismissing(ilead_time)) then
      continue
   end if
   print("reading file "+files(nf))
   t1 = addfile(files(nf),"r")
   if(.not.isfilevar(t1,fieldname))then
	print(fieldname+" not in "+files(nf))
	continue
   end if
   field = t1->$fieldname$ - field_init
   copy_VarCoords(t1->$fieldname$, field)
   if (dimsizes(dsizes).eq.2) then
     diff(ilead_time,:,:) = (/ field /) ; don't think I needed array notation for GFS. . . 
     sqdiff(ilead_time,:,:) = field^2 
   end if
   if (dimsizes(dsizes).eq.3) then
     diff(ilead_time,:,:,:) = field
     sqdiff(ilead_time,:,:,:) = field^2 
   end if
   nfile(ilead_time) = nfile(ilead_time)+1
   delete(t1)
end do

ncdf->diff = diff
copy_VarCoords(diff,sqdiff)
ncdf->sqdiff = sqdiff
ncdf->nfile = nfile



print("processing success")

end

;=============================================================================================
