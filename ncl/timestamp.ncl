undef("add_timestamp")
function add_timestamp(ofile)
local cmd
begin
    timestamp = systemfunc("date '+%b %d %Y %T %Z'")
    cmd = "mogrify -trim -bordercolor white -border 5 +repage -type Palette -gravity Southwest -pointsize 9 -annotate +0+0 'created "+timestamp+"' -colors 255 "+ofile
    print(cmd)
    return_val = systemfunc(cmd)
    return(return_val)
end
