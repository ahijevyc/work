; Functions to plot different symbols
; adding TC symbol http://www.ncl.ucar.edu/Support/talk_archives/2012/3195.html

undef("create_hurricane_symbol")
function create_hurricane_symbol(wks,lat,vmax)
begin

  fontnum = 19
  mstring = "x"
  
  if(vmax .lt. 34) then
    return(4); hollow circle
  end if

  fontnum = 35
  mstring = "m" ; NH tropical storm
  if(lat .lt. 0) then 
    mstring = "k" ; SH
  end if

  if(vmax .ge. 64) then
    fontnum = 37
    mstring = "p" ; NH hurricane
    if(lat .lt. 0) then
      mstring = "s" ; SH hurricane
    end if
  end if
  
  
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.0
  size    = 1.2
  angle   = 0.0

  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, \
                           ratio, size, angle)

  return(new_index)
end

