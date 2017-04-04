undef("cd_inv_string") ; kludge until ncl version 6.4 is released (It will have this function)
function cd_inv_string(str_time: string, format: string)

; Input
; str_time : variable of type string. It may have any dimensionality.
;
; Returns number of hours since 1970-01-01 00:00:00 (type double).
; It will have same dimensionality as input str_time.
; 


local len, yyyy, mm, dd, hh, mn, sc
begin
	len = strlen(str_strip(str_time))
	if(any(len.eq.19))then
		; assumes format YYYY-MM-DD_HH:MM:SS
		yyyy = toint(str_get_cols(str_time,0,3))
		mm = toint(str_get_cols(str_time, 5,6))
		dd = toint(str_get_cols(str_time, 8,9))
		hh = toint(str_get_cols(str_time, 11,12))
		mn = toint(str_get_cols(str_time, 14,15))
		sc = toint(str_get_cols(str_time, 17,18))
	end if
	if(any(len.eq.18))then
		; assumes format MM/DD/YYYY (HH:MM)
		mm = toint(str_get_cols(str_time, 0,1))
		dd = toint(str_get_cols(str_time, 3,4))
		yyyy = toint(str_get_cols(str_time,6,9))
		hh = toint(str_get_cols(str_time, 12,13))
		mn = toint(str_get_cols(str_time, 15,16))
		sc=0
	end if
	if(any(len.eq.10))then
		; assumes format YYYYMMDDHH
		yyyy = toint(str_get_cols(str_time,0,3))
		mm = toint(str_get_cols(str_time, 4,5))
		dd = toint(str_get_cols(str_time, 6,7))
		hh = toint(str_get_cols(str_time, 8,9))
		mn = 0
		sc = 0
	end if
	if(.not.isvar("yyyy"))then
		print("could not get calendar from "+str_time)
	end if
	return(cd_inv_calendar(yyyy,mm,dd,hh,mn,sc,"hours since 1970-01-01 00:00:00",0))
end
