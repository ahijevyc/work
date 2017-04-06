undef("sscript")
function sscript (x:string)
local is, xi, afterpart, xout, fixedpart
begin
	
	; look for "^{"
	if(ismissing(str_match(x,"^{")))then
		return(x)
	end if
	is = str_index_of_substr(x, "^{", 0)
	xout = "" ; reinitialize as empty string
	; go through each superscript one at a time
	do xi=0,dimsizes(is)-1
		; index of first "^{" in working string
		i = str_index_of_substr(x, "^{", 1)
		; look for "}" after "^{"
		afterpart = str_get_cols(x,i+2,-1)
		if(ismissing(str_match(afterpart, "}")))then
			return(x)
		end if
		j = str_index_of_substr(x, "}", 1)
		fixedpart = str_get_cols(x,0,i-1) + "~S~"+str_get_cols(x,i+2,j-1)+"~N~"
		; append fixed part 
		xout = xout + fixedpart
		; chop off fixed part of working string
		x = str_get_cols(x, j+1, -1)
	end do

	return(xout)
end
