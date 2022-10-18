undef("first_match")

; loop through array of possible strings; return first matching element

function first_match(possible_strings[*]:string, infile_strings[*]:string)
begin
    do i = 0, dimsizes(possible_strings)-1
        possible_match = possible_strings(i)
        if (any(infile_strings.eq.possible_match)) then
            return(possible_match)
        end if
    end do ; possible strings
end


undef("find_match_dim")
function find_match_dim(possible_strings [*]:string, f:file)
; Input
;	possible_strings:
;		array of possible dimension names (strings)
;
; Output
;	first string that matches a dimension in the file
;
begin
    dimnames = getfiledimnames(f)
    return first_match(possible_strings, dimnames)
end


undef("find_match_var")
function find_match_var(possible_strings [*]:string, f:file)
; Input
;	possible_strings:
;		array of possible variable names (strings)
;
; Output
;	first string that matches a variable in the file
;
begin
    varnames = getfilevarnames(f)
    return first_match(possible_strings, varnames)
end

