;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;=============================================================================================

; May be driven by ~/bin/run_fcst-init_comp.csh

; Average fcst-init differences from many valid times.  
; and plot a map of the variable 'fieldname'.
; If mpas and fieldname are not supplied on command line, mpas and precipw are assumed.


begin
; Set default values if not provided on command line. For example, ncl 'mpas="mpas"' 'fieldname="precipw"' . 
if(.not.isvar("mpas")) then
   mpas="mpas"
end if
if(.not.isvar("fieldname")) then
   fieldname="s10"
end if
if(.not.isvar("year")) then
   year="2014"
end if
if(.not.isvar("outdir")) then
	outdir="/glade/p/work/ahijevyc/rmse_comparisons/"+mpas
end if

; run on a composite created with nces in ~ahijevyc/bin/run_fcst-init.sh 
; (if you can't seem to get anything, make sure first file is not emtpy .nc file (1024 bytes)
; fcst-init.ncl makes an empty .nc file if there are no earlier forecasts, like for 1st date in time window.

diff_name = outdir+"/"+fieldname+"_avg_"+year
mse_name = outdir+"/"+fieldname+"_avgsqr_"+year
ttl_name = outdir+"/"+fieldname+"_ttl_"+year+".nc"

basedir = "/glade/p/nmmm0031/"+mpas+"/"

iop0 = 0
iop1 = 1
if(fieldname .eq. "vect10") then
	iop0 = 1
end if
if(fieldname .eq. "mse") then
	iop1 = 0
end if
ttl = addfile(ttl_name,"r")
nfile = ttl->nfile
delete(ttl)
do iop = iop0, iop1
	if(iop .eq. 0) then 
		op = diff_name
		desc = "difference field for "+fieldname
	else
		op = mse_name
		; Read MSE. Square root will be taken later.
		desc = "rmse for "+fieldname
	end if
	t1 = addfile(op+".nc","r")

	if(fieldname .eq. "vect10") then 
		field = t1->sqdiff
	else
		field = t1->diff
	end if

	lead_time = t1->lead_time
	delete(t1)

	wks = gsn_open_wks("png",op)

	; added this to plot mse. it choked with only 100,000,000. 
        ;setvalues NhlGetWorkspaceObjectId()
	;   "wsMaximumSize":200000000
	;end setvalues

	;SET RESOURCES:
	res = get_field_res(wks,desc,field)
	; if this is mean squared difference MSE take the sqrt().
	if(iop.eq.1)then
		field = sqrt(field)
	end if
	ff = addfile(basedir+year+"090100/init.nc","r")
	extrastride=1
	res = set_res_sf(res, ff, field, extrastride)
	delete(ff)

	;loop over the number of days:
	do nf = 0,10
	   res@tiMainString = mpas+sprintf("%3.0f",lead_time(nf))+"d fcst - init, avg of "+sprintf("%2.0f",nfile(nf))+" files"
	   res@gsnLeftString = desc
	   print(min(field(nf,0,0::extrastride)))
	   print(max(field(nf,0,0::extrastride)))
	   plot = gsn_csm_contour_map(wks,field(nf,0,0::extrastride),res)
           draw(plot)
           frame(wks)
	   delete(plot)
	end do
	delete(wks)
	delete(res)
	print("made "+op)

end do
end

;=============================================================================================
