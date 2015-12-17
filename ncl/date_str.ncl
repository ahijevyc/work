undef("date_str")
function date_str(time:numeric)
begin
  ; Array to hold month abbreviations. Don't store anything in index
  ; '0' (i.e. let index 1=Jan, 2=Feb, ..., index 12=Dec).
  ;
  month_abbr = (/"","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep", \
                    "Oct","Nov","Dec"/)
  utc_date = cd_calendar(time, 0)
  year   = tointeger(utc_date(:,0))    ; Convert to integer for
  month  = tointeger(utc_date(:,1))    ; use sprinti 
  day    = tointeger(utc_date(:,2))
  hour   = tointeger(utc_date(:,3))
  minute = tointeger(utc_date(:,4))
  second = utc_date(:,5)
  return(sprinti("%0.2i", hour) + sprinti("%0.2iZ ", minute) + sprinti("%0.2i ", day) + \
              month_abbr(month) + " "  + sprinti("%0.4i", year))

end
