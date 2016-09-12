;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
;=============================================================================================

; Mask domain outside of area of interest (e.g. NH = 20-80N)
undef("mask_inv")
function mask_inv(x:numeric, ji:numeric)
begin
	; Fanglin Yang (NOAA Affiliate <fanglin.yang@noaa.gov>) says
	; for NH 20-80N 20 and 80 are inclusive
	ds = dimsizes(x)
	nrank = dimsizes(ds)
	mt = x
	mt = x@_FillValue
	if(nrank.eq.2)then
		mt(ji(0):ji(1),ji(2):ji(3)) = x(ji(0):ji(1),ji(2):ji(3))
	end if
	if(nrank.eq.3)then
		mt(:,ji(0):ji(1),ji(2):ji(3)) = x(:,ji(0):ji(1),ji(2):ji(3))
	end if
	return mt

end

; Grab 4X-daily 30-year climatology.
undef("get_4Xday")
function get_4Xday(climo_file:file, field:numeric)
begin
	vars = getfilevarnames(climo_file)
	do i=0,dimsizes(vars)-1
		if(isatt(climo_file->$vars(i)$,"statistic"))then
			cstr = vars(i)
		end if
		; Before using the 1958-1988 climo files, I had to follow the procedure in 
		; /glade/p/work/ahijevyc/mpas_plots/README
		if(isatt(climo_file->$vars(i)$,"level_indicator"))then
			lvl_indicator = climo_file->$vars(i)$@level_indicator
			if(isatt(field,"level_type"))then
				lvl_type = field@level_type
				if((lvl_type.eq."Specified height level above ground (m)".and.lvl_indicator.eq.105).or.\
				   (lvl_type.eq."Isobaric surface (Pa)" .and. lvl_indicator.eq.100) )
					cstr = vars(i)
				end if
			else
				print("no level_type attribute. not using "+vars(i))
			end if
		end if
	end do
	print("using "+cstr+" from climo_file")
	climo = climo_file->$cstr$
	climotime=climo_file->time
	yyyymmddhh = cd_calendar(climotime(0),-3) ; returns integer. divide by 1000000 to get year
	yyyy = yyyymmddhh/1000000
	climo0 = field
	climo0 = new(dimsizes(field),typeof(field))
	copy_VarMeta(field, climo0)

	; Get valid time
	if(isatt(field,"initial_time"))then
		; GFS has "initial_time" attribute
		t = field@initial_time
		month = str_get_cols(t,0,1)
		day = str_get_cols(t,3,4)
		hour = str_get_cols(t,12,13)
		minute = str_get_cols(t,15,16)
		valid = cd_inv_calendar(yyyy,toint(month),toint(day),toint(hour),toint(minute),0,climotime@units, 0)
		if(isatt(field,"forecast_time"))then
			if(field@forecast_time_units.eq."hours")then
				valid = valid + field@forecast_time
			else
				exit
			end if
		end if
	else
		; MPAS has xtime variable
		if(isatt(field,"xtime"))then
			t = tostring(field@xtime)
			month = str_get_cols(t,5,6)
			day  = str_get_cols(t,8,9)
			hour = str_get_cols(t,11,12)
			minute = str_get_cols(t,14,15)
			sec = str_get_cols(t,17,18)
			; important to use yyyy, which is year 1 or something
			valid = cd_inv_calendar(yyyy,toint(month),toint(day),toint(hour),toint(minute),toint(sec),climotime@units, 0)
		else
			print("did not get time from field")
			printVarSummary(field)
			exit
		end if
	end if
	; Find index of climatology time dimension that matches valid time
	itime = ind(climotime.eq.valid)
	if(ismissing(itime))then
		print(climotime)
		print(valid)
		exit
	end if

	; Get the vertical dimension levels of climatology
	if(any(getfilevarnames(climo_file).eq."level"))then
		climolevel = climo_file->level
		if(isatt(climolevel,"units"))then
			if(climolevel@units.ne."millibar".and.climolevel@units.ne."hPa")then
				exit
			end if
		end if
	end if

	; Interpolate climatology to forecast mesh/grid
	if(any(getvardims(field).eq."nCells"))then
		if(any(getfilevarnames(climo_file).eq."level"))then
			ilev = ind(climolevel.eq.climo0@level)
			if(.not.ismissing(ilev))then
				printVarSummary(climo0)
				printVarSummary(climo)
				climo0(0,:) = (/ linint2_points_Wrap(climo&lon,climo&lat(::-1),climo(itime,ilev,::-1,:),True,field@lonCell,field@latCell,0) /)
			end if
		else
			climo0(0,:) = linint2_points_Wrap(climo&lon,climo&lat(::-1),climo(itime,::-1,:),True,field@lonCell,field@latCell,0)
		end if
	else
		opt = True
		opt@bin_factor = dimsizes(field&lat_0)*dimsizes(field&lon_0)/dimsizes(climo&lat)/dimsizes(climo&lon)
		vardims = getvardims(field)
		iVert = ind(str_get_cols(vardims,0,2).eq."lv_")
		; See if field has a vertical dimension
		if(.not.any(ismissing(iVert)))then
			; If field has a vertical dimension grab it.
			levels = field&$vardims(iVert)$
			; Find correct index of vertical dimension.
			do flev=0,dimsizes(levels)-1
				ilev = ind(100*climolevel.eq.levels(flev))
				if(.not.ismissing(ilev))then
					climo0(flev,:,:) = area_conserve_remap_Wrap(climo&lon,climo&lat(::-1),climo(itime,ilev,:,:),field&lon_0,field&lat_0(::-1),opt)
				end if
			end do
		else
			climo0 = area_conserve_remap_Wrap(climo&lon,climo&lat(::-1),climo(itime,:,:),field&lon_0,field&lat_0(::-1),opt)
		end if
		; flip back to N-S after flipping to S-N for area_conserve_remap_Wrap or linint2_points_Wrap
		climo0&lat_0 = climo0&lat_0(::-1)
	end if
	return climo0
end


; Main script.
begin

; this NCL script run by ~ahijevyc/bin/run_fcst-init.sh 
;
; Set default values if not provided on command line. For example, ncl "date=2013091500" 'mpas="mpas"' 'field_name="q2"' . 
if(.not.isvar("workdir")) then
	; hard-wired to ahijevyc for post-post-processing. Could be $USER
	workdir="/glade/scratch/ahijevyc/"
end if
if(.not.isvar("mpas")) then
	mpas="mpas50_3"
end if
if(.not.isvar("field_name")) then
	field_name="height_500hPa"
end if
if(.not.isvar("date")) then
	date="2015051400"
end if

outdir = workdir+mpas+"/"+date+"/"

syear = str_get_cols(date,0,3)
if(.not.isvar("climo_file"))then
	climo_file = "/glade/p/work/ahijevyc/mpas_plots/air.4Xday.1981-2010.ltm.nc"
	climo_file = "/glade/p/work/ahijevyc/mpas_plots/air.4Xday.1959-1988.ltm.nc"
end if
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
	print("No "+dird+"diag*."+xtime2+".00.00.nc files found. need at least 1.")
	exit
end if

; Find t=0 forecast (analysis)
analysis_file = files(nfiles-1)
; make sure last item in list of forecasts is the 0-h forecast, in other words, it is in the requested date directory.
if(ismissing(str_index_of_substr(analysis_file,"/"+date,0))) then
	print("looked for /"+date+" in analysis_file. "+analysis_file+ " not in the requested date directory")
	print("or did you include hours in your date request? Don't do that.")
	exit
end if

print("reading analysis_file "+analysis_file)
ff = addfile(analysis_file,"r")
analysis = ff->$field_name$
;printMinMax(analysis,False)
if(all(analysis.eq.0))then
	print("all "+field_name+" zero in analysis "+analysis_file+". Skipping.")
	exit
end if
if(max(analysis)-min(analysis).lt.2e-15)then
	printMinMax(analysis,False)
	print("all "+field_name+" similar in analysis "+analysis_file+". Skipping.")
	exit
end if

; Find climatological average
if(.not.isfilepresent(climo_file))then
	print("climo_file '"+climo_file+"' not found. No anomaly without climatology.")
	exit
end if

if(any(getvardims(analysis).eq."nCells"))then
	init_file = "/glade/p/work/ahijevyc/mpas_plots/"+mpas+"/init.nc"
	print("reading "+init_file+" for areaCell")
	init_file := addfile(init_file,"r")
	areaCell = init_file->areaCell
	areaCell := conform(analysis,areaCell,1)
	r2d = 180./3.141592
	latCell = init_file->latCell*r2d
	lonCell = init_file->lonCell*r2d
	; Save latCell and lonCell, which are used to mask domains.
	analysis@lonCell = lonCell
	analysis@latCell = latCell
	; get_4Xday needs initial_time/forecast_time or xtime
	analysis@xtime = ff->xtime
	if(str_get_cols(field_name,-3,-1).eq."hPa")then
		i = str_index_of_substr(field_name,"_",-1)
		hPa := str_get_cols(field_name,i+1,str_index_of_substr(field_name,"hPa",-1)-1)
		analysis@level = hPa
		analysis@level_type = "Isobaric surface (Pa)"
	end if
	if(str_get_cols(field_name,-2,-1).eq."10".or.str_get_cols(field_name,-3,-1).eq."10m")then
		analysis@level_type = "Specified height level above ground (m)"
		analysis@level = 10
	end if
	if(str_get_cols(field_name,-1,-1).eq."2".or.str_get_cols(field_name,-2,-1).eq."2m")then
		analysis@level_type = "Specified height level above ground (m)"
		analysis@level = 2
	end if
end if
climo = addfile(climo_file,"r")
climo := get_4Xday(climo,analysis)
if(.not.isatt(climo,"_FillValue"))then
	climo@_FillValue = default_fillvalue(typeof(climo))
end if

ncfile = outdir+field_name+"_f-i.nc"
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
globalAtt@field_name=field_name
globalAtt@workdir=workdir
globalAtt@analysis_file=analysis_file
globalAtt@fcst_files=files(0:nfiles-1)
globalAtt@climatology_file = climo_file
fileattdef( ncdf, globalAtt )


; used to start at 1d to save space, but this complicated mpas_basin_rmse.pro
lead_times = (/ 0d, 1d, 2d, 3d, 4d, 5d, 6d, 7d, 8d, 9d, 10d /)
dsizes = dimsizes(analysis)
if (mpas.eq."GFS".or.mpas.eq."GFS_00Z") then 
	lead_times := fspan(0.d, 8d, 33) ; shorten from 10 to 8 days for GFS and do every 6 hours
	lead_times := fspan(0.d, 5d, 6) ; just do 5 days
end if

filedimdef(ncdf,"lead_time",-1,True)
lead_times@long_name = "lead time"
lead_times@units = "days"
nfile = new( (/ dimsizes(lead_times) /), typeof(lead_times))
nfile = 0
nfile!0 = "lead_time"
nfile&lead_time = lead_times
; Make new difference field like analysis, but prepend "lead_time" dimension.
dimsPlus1 = new(dimsizes(dsizes)+1,integer)
dimsPlus1(0) = dimsizes(lead_times)
dimsPlus1(1:) = dsizes
diff = new(dimsPlus1, typeof(analysis))
diff!0 = "lead_time"
diff&lead_time = lead_times
diff@long_name = "difference field for "+field_name

; assign dimension names from analysis to diff field
; and if named dimension has a coordinate variable, assign it.
; and save to netcdf output file.
do idim = 0, dimsizes(dsizes)-1 
	diff!(idim+1) = analysis!idim
	if(iscoord(analysis,analysis!idim))then
		diff&$analysis!idim$ = analysis&$analysis!idim$
		ncdf->$analysis!idim$ = ff->$analysis!idim$
	end if
end do

sqdiff = diff
sqdiff@long_name = "squared " + diff@long_name

Fanom2 = diff
Fanom2@long_name = field_name + " forecast anomaly squared"

FanomOanom = diff
FanomOanom@long_name = field_name + " forecast anomaly times observation anomaly"

ACC = diff
dimnames = getvardims(diff)
area_dims = ind(dimnames.eq."nCells".or.dimnames.eq."lat_0".or.dimnames.eq."lon_0")
ACC := dim_avg_n_Wrap(diff, area_dims)
ACC@long_name = "anomaly correlation coefficent"
ACC@domain = "global"
ACC@lat_min =  -90.
ACC@lat_max =   90.
ACC@lon_min =    0.
ACC@lon_max =  360.
ncdf->ACC = ACC
ACC_NH = ACC
ACC_NH@domain = "Northern Hemisphere"
ACC_NH@lat_min =    20.
ACC_NH@lat_max =    80.
ncdf->ACC_NH = ACC_NH
ACC_NA = ACC
ACC_NA@domain = "North America"
ACC_NA@lat_min =   15.
ACC_NA@lat_max =   75.
ACC_NA@lon_min = -160.+360
ACC_NA@lon_max =  -55.+360
ncdf->ACC_NA = ACC_NA

if(any(dimnames.eq."lon_0"))then
	; needed for getting domain with region_ind().
	lat2D = conform_dims((/dimsizes(climo&lat_0),dimsizes(climo&lon_0)/),climo&lat_0,0)
	lon2D = conform_dims((/dimsizes(climo&lat_0),dimsizes(climo&lon_0)/),climo&lon_0,1)
end if
	


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
	t1 = addfile(files(nf),"r")
	if(.not.isfilevar(t1,field_name))then
		print(field_name+" not in "+files(nf))
		continue
	end if
	print("reading lead_time "+tostring(lead_time)+" forecast file "+files(nf))
	forecast = t1->$field_name$
	;printMinMax(forecast,False)
	delta = forecast - analysis
	copy_VarCoords(forecast, delta)
	if(False)then
		; Subtract forecast climatology from forecast as opposed to subtracting analysis climatology.
		 climo_file = "/glade/p/work/ahijevyc/mpas_plots/"+mpas+"/"+syear+".f"+sprintf("%03.0f",lead_time*24)+".nc"
		 Fclimo := addfile(climo_file,"r")
		 Fclimo := Fclimo->$field_name$
	else
		 Fclimo = climo
	end if

	if (dimsizes(dsizes).eq.2) then
		diff(ilead_time,:,:) = (/ delta /) ; avoid warning "dimension names for number (0) don't match" by using parentheses.
		sqdiff(ilead_time,:,:) = delta^2 
		Fanom2(ilead_time,:,:) = (forecast - Fclimo)^2.
		FanomOanom(ilead_time,:,:) = (forecast - Fclimo) * (analysis-climo)
	end if
	if (dimsizes(dsizes).eq.3) then
		diff(ilead_time,:,:,:) = delta
		sqdiff(ilead_time,:,:,:) = delta^2 
		Fanom2(ilead_time,:,:,:) = (forecast - Fclimo)^2.
		FanomOanom(ilead_time,:,:,:) = (forecast - Fclimo) * (analysis-climo)
	end if
	vardims = getvardims(forecast)
	ndim = dimsizes(vardims)

	ACCs = str_match(getfilevarnames(ncdf),"ACC")
	do j=0,dimsizes(ACCs)-1
		ACCname = ACCs(j)	
		; get area-weighted spatial average for ACC.
		lat_min = ncdf->$ACCname$@lat_min
		lat_max = ncdf->$ACCname$@lat_max
		lon_min = ncdf->$ACCname$@lon_min
		lon_max = ncdf->$ACCname$@lon_max
		mclimo = climo
		
		if(vardims(ndim-2).eq."lat_0".and.vardims(ndim-1).eq."lon_0")then
			wgty = cos(t1->lat_0/180*3.141592)
			; use _Wrap version of wgt_areaave to preserve _FillValue (important for domain mask) 
			ji = region_ind(lat2D,lon2D,lat_min,lat_max,lon_min,lon_max)
			mclimo = mask_inv(mclimo, ji)
			if(dimsizes(dimsizes(forecast)).gt.2)then
				fprime = (forecast-mclimo)-conform(mclimo,wgt_areaave_Wrap(forecast-mclimo,wgty,1.,1),0)
				oprime = (analysis-mclimo)-conform(mclimo,wgt_areaave_Wrap(analysis-mclimo,wgty,1.,1),0)
			else
				fprime = (forecast-mclimo)-wgt_areaave_Wrap(forecast-mclimo,wgty,1.,1)
				oprime = (analysis-mclimo)-wgt_areaave_Wrap(analysis-mclimo,wgty,1.,1)
			end if
			numerator = wgt_areaave_Wrap(fprime*oprime,wgty,1.,1)
			denominator = sqrt(wgt_areaave_Wrap(fprime^2.,wgty,1.,1)*wgt_areaave_Wrap(oprime^2.,wgty,1.,1))
		else
			if(vardims(ndim-1).ne."nCells")then
				exit
			end if
			; isolate domain on MPAS mesh
			m := latCell.lt.lat_min.or.latCell.gt.lat_max.or.lonCell.lt.lon_min.or.lonCell.gt.lon_max
			if(any(m))then
				mclimo(:,ind(m)) = getFillValue(climo)
				; Soyoung found this error. I should mask areaCell too, because I take the sum of it in the denominator below.
				areaCell(ind(m)) = getFillValue(areaCell)
			end if
			fprime = (forecast-mclimo)-sum((forecast-mclimo)*areaCell)/sum(areaCell)
			oprime = (analysis-mclimo)-sum((analysis-mclimo)*areaCell)/sum(areaCell)
			numerator = sum(fprime*oprime*areaCell)/sum(areaCell)
			denominator = sqrt(sum(fprime^2.*areaCell)/sum(areaCell)*sum(oprime^2.*areaCell)/sum(areaCell))
		end if
		if(False)then
			; Output for debugging.
			tmp_file = ACCname+sprintf("%02.0fd",lead_time)+".nc"
			system("/bin/rm -fv "+tmp_file)
			t := addfile(tmp_file,"c")
			t->climo = climo
			t->forecast = forecast
			t->mclimo = mclimo
			x := forecast-mclimo
			copy_VarMeta(forecast,x)
			t->x = x
			copy_VarMeta(forecast,fprime)
			t->fprime = fprime
			t->y = analysis-mclimo
			copy_VarMeta(analysis,oprime)
			t->oprime = oprime
		end if
		if(any(getvardims(ncdf->$ACCname$).ne."lead_time"))then
			ncdf->$ACCname$(ilead_time,:) = numerator/denominator
		else
			ncdf->$ACCname$(ilead_time) = numerator/denominator
		end if
	end do

	nfile(ilead_time) = nfile(ilead_time)+1
	delete(t1)
end do

ncdf->diff = diff
if(field_name.eq."vect10")then
	ncdf->sqdiff = sqdiff
end if
ncdf->nfile = nfile
ncdf->Fanom2 = Fanom2
ncdf->FanomOanom = FanomOanom

print("processing success")

end

;=============================================================================================
