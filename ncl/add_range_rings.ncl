undef("add_range_rings")
function add_range_rings(wks:graphic,map:graphic)
local lnres, radar_range
begin

    ; TODO: input lat/lon/range/labels

    lnres             = True
    lnres@gsLineThicknessF = 4.

    radar_range = 150.
    ;Get latitude/longitude of a circle around SPOLKA
    get_circle = geolocation_circle(24.819113,120.907526,radar_range,1,100,0)
    SPK_clat = get_circle[0]
    SPK_clon = get_circle[1]
    circle1 = gsn_add_polyline(wks,map,SPK_clon(0,0,:),SPK_clat(0,0,:),lnres)

    ;Repeat for SEAPOL
    get_circle = geolocation_circle(24.46,122.94,radar_range,1,100,0)
    SPL_clat = get_circle[0]
    SPL_clon = get_circle[1]
    circle2 = gsn_add_polyline(wks,map,SPL_clon(0,0,:),SPL_clat(0,0,:),lnres)

    ;add "H" and "Y" for Hsinchu and Yonaguni
    txres = True
    txres@txFontHeightF = 0.018
    Hlab = gsn_add_text(wks,map,"H",120.907526,24.819113,txres)
    Ylab = gsn_add_text(wks,map,"Y",122.94,24.46,txres)

end
