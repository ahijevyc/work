;=============================================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "/glade/p/work/ahijevyc/ncl/get_field_res.ncl"
load "/glade/p/work/ahijevyc/ncl/derived_fields.ncl"
;=============================================================================================

; Did this for "mpas_conv" so far.
begin
if (.not.isvar("mesh")) then
	mesh = "mpas_conv"
end if
if (.not.isvar("domain")) then
	domain = mesh
end if
basedir = "/glade/p/work/ahijevyc/mpas_plots/"+mesh+"/"

t1 = addfile(basedir+mesh+"_rain.nc","r")
iTime = 0
fieldname = "rainc240h"
wks = gsn_open_wks("png",basedir+mesh+"_mesh."+domain+"_domain."+fieldname)
# Grab "prefix" (all characters of fieldname except final 4)
prefix = str_get_cols(fieldname, 0, -5)
field = t1->$prefix$(iTime,:)
res = get_field_res(wks, fieldname, field)
res = set_res_mp(res, domain)
idir = "/glade/p/nmmm0031/"+mesh+"/"
res = set_res_sf(res, addfile(idir+"2015082600/init.nc","r"), field, 1) 
res@gsnCenterString = mesh + " mesh"
# Nudge center string to the right.(default is center, or 0.5)
res@gsnCenterStringParallelPosF = 0.6
plot = gsn_csm_contour_map(wks,field,res)
draw(plot)
frame(wks)

print("processing success "+wks@name)

end

;=============================================================================================
