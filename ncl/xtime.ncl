; Functions 

undef("fhour_xtime")
function fhour_xtime(init,fcst)
begin
    ; Input:
    ; init : yyyy-mm-dd_hh character array or yyyymmddhh string
    ; fcst : yyyy-mm-dd_hh string
    ; forecast hour

    if(strlen(init).eq.10)then
        ; Assume yyyymmddhh format
        i_xtime  = init
        iyear  = stringtoint(str_get_cols(init, 0, 3))
        imonth = stringtoint(str_get_cols(init, 4, 5))
        iday   = stringtoint(str_get_cols(init, 6, 7))
        ihour  = stringtoint(str_get_cols(init, 8, 9))
    else
        ; Assume yyyy-mm-dd_hh format
        i_xtime = chartostring(init->xtime)
        iyear  = stringtoint(str_get_cols(i_xtime,  0,  3))
        imonth = stringtoint(str_get_cols(i_xtime,  5,  6))
        iday   = stringtoint(str_get_cols(i_xtime,  8,  9))
        ihour  = stringtoint(str_get_cols(i_xtime, 11, 12))
    end if

    f_xtime = chartostring(fcst->xtime)
    fyear  = stringtoint(str_get_cols(f_xtime,  0,  3))
    fmonth = stringtoint(str_get_cols(f_xtime,  5,  6))
    fday   = stringtoint(str_get_cols(f_xtime,  8,  9))
    fhour  = stringtoint(str_get_cols(f_xtime, 11, 12))

    lead_day = greg2jul(fyear,fmonth,fday,fhour) - greg2jul(iyear,imonth,iday,ihour)
    if(lead_day .lt. 0) then
        print(f_xtime + "-" + i_xtime)
        print("negative lead time")
        status_exit(1)
    end if
    ; round to nearest 0.001 hour
    return(round(lead_day*24.*1000,0)/1000)
end

