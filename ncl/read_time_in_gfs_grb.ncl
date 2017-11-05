; read_time_in_gfs_grb.ncl

undef("read_time_in_gfs_grb")
function read_time_in_gfs_grb(x)
;**************************************************************************
; Read time info for the variable x (read from the GFS grib data in netcdf)
; Soyoung Ha (MMM/NCAR) 09-07-2016
; 
; Variable: x
; Type: float
; Number of Dimensions: 3
; Dimensions and sizes:	[lv_ISBL0 | 26] x [lat_0 | 361] x [lon_0 | 720]
; Coordinates: 
;             lv_ISBL0: [1000..100000]
;             lat_0: [90..-90]
;             lon_0: [ 0..359.5]
; Number Of Attributes: 12
;   initial_time :	08/18/2014 (00:00)
;   forecast_time_units :	hours
;   forecast_time :	0
;   level_type :	Isobaric surface (Pa)
;   units :	gpm
;   long_name :	Geopotential height
;   production_status :	Operational products
;   center :	US National Weather Service - NCEP (WMC)
; 
; => Returnning variable: 
; Variable: ta
; Type: string
; Total Size: 8 bytes
;            1 values
; Number of Dimensions: 1
; Dimensions and sizes:	[1]
; Coordinates: 
; (0)	2014-08-18_00:00:00
;**************************************************************************

begin

if(.not.isatt(x,"initial_time")) then
   print("This variable does not have an expected time information. Stop.")
   exit
end if

   t0 := x@initial_time
   mo := toint(str_get_cols(t0,0,1))
   dy := toint(str_get_cols(t0,3,4))
   yr := toint(str_get_cols(t0,6,9))
   hr := toint(str_get_cols(t0,12,13))
   mn := toint(str_get_cols(t0,15,16))

  if(isatt(x,"forecast_time")) then
     if(x@forecast_time_units.eq."hours") then
       hr := hr + x@forecast_time
     else
       print("forecast_time_units is not hr: "+x@forecast_time_units)
       exit
     end if
  end if
  ; Allow for "forecast_time0" in addition to "forecast_time"
  ; Assume units are hours. Should probably check.
  if(isatt(x,"forecast_time0")) then
     hr := hr + x@forecast_time0
  end if
  
  unit:= "hours ref 1-1-1 00:00:0.0"
  tcal:= cd_inv_calendar(yr,mo,dy,hr,mn,0,unit,0)    
    t := cd_calendar(tcal,0) 
   yr := toint(t(:,0))
   mo := toint(t(:,1))
   dy := toint(t(:,2))
   hr := toint(t(:,3))
   mn := toint(t(:,4))

   xtime := yr + "-" + sprinti("%0.2i",mo) + "-" + sprinti("%0.2i",dy) + "_" + sprinti("%0.2i",hr) + ":" + sprinti("%0.2i",mn) + ":00"
   return(xtime)

end
;**************************************************************************
