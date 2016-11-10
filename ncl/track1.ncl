load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "/glade/p/work/ahijevyc/ncl/read_atcf.ncl"

begin

; Set return character
cr = "~C~"

;----------------------------------------------------------------------
; Read storm track and info
;----------------------------------------------------------------------

; What am I reading (NowReading)
; AFWA track info 
; RIP4 track info 

;NowReading = "RIP4"
;NowReading = "AFWA"
NowReading = "ADECK"
;type       = "x11"
;type       = "ncgm"
type       = "pdf"
type       = "png"
storm      = "Joaquin (2015)"
Files      = "Files.joaquin"
btFile     = "bal112015.dat"

if(.not.isvar("model"))then
	model = "MPAS"
end if
; set up header
  track = model+" Forecasts"
  if ( storm .ne. "Unknown" ) then
    track = track + ": " + storm + " "
  end if

  wks = gsn_open_wks(type,model+"_track")  

;----------------------------------------------------------------------
; Set up the window
;----------------------------------------------------------------------

  min_lat  =  15.0
  max_lat  =  60.0
  min_lon  = -86.0
  max_lon  = -15.0

;----------------------------------------------------------------------
; Set up resources and create map
;----------------------------------------------------------------------

  gsn_define_colormap(wks,(/"White","Black","Azure4","LightBlue","SandyBrown", \ 
                            "Coral","Blue","DarkGreen","Orange","Red", \
                            "Purple3","CadetBlue4","Olivedrab1","Green","Orchid1", \
                            "Cyan","CornFlowerBlue","Magenta","NavyBlue","LightGrey"/))
;
; Set some resources. And Zoom in on the map.
;
  res             = True
  res@gsnMaximize = True     ; Maximize plot size in the frame.
  res@gsnDraw     = False    ; Don't draw the plot just yet.
  res@gsnFrame    = False    ; Don't advance the frame just yet.
  res@mpMinLatF   =  min_lat
  res@mpMaxLatF   =  max_lat
  res@mpMinLonF   =  min_lon
  res@mpMaxLonF   =  max_lon
  res@mpOutlineBoundarySets = "GeophysicalAndUSStates"
  res@mpDataBaseVersion = "HighRes"
; res@mpFillColors = (/"background","LightBlue","SandyBrown","LightBlue", \
;                      "transparent"/)
  res@mpGeophysicalLineColor      = 2
  res@mpGeophysicalLineThicknessF = 0.75
  res@mpGridLineColor             = 2
  res@mpGridLineThicknessF        = 0.75
  res@mpGridMaskMode              = 3
  res@mpGridSpacingF              = 5
  res@mpLimbLineColor             = 2
  res@mpLimbLineThicknessF        = 0.75
  res@mpNationalLineColor         = 2
  res@mpNationalLineThicknessF    = 0.75
  res@mpUSStateLineColor          = 2
  res@mpUSStateLineThicknessF     = 0.75
;
; Tickmark stuff.
;
  res@pmTickMarkDisplayMode   = "Always"
  res@tmXBMajorOutwardLengthF = 0.0
  res@tmXBMajorLengthF = 0.0
  res@mpGridAndLimbOn         = True
  res@mpOutlineOn             = True
  res@tmXBLabelFontHeightF    = 0.008
;
; Just create the map. It won't get drawn because we set gsnDraw to False.
;
  map = gsn_csm_map(wks,res)
;
; Set some marker resources.
;
  pmres               = True
  pmres@gsMarkerIndex = 1
  pmres@gsMarkerOpacityF = 0.9
;
; Set some line resources.
;
  lnres                  = True
  lnres@gsLineColor      = "Black"
; lnres@gsLineThicknessF = 4.0
  lnres@gsLineOpacityF = 0.9
;
; Set some text resources.
;
  txres               = True
  txres@txFont        = "helvetica" 
  txres@txFontHeightF = 0.009  
  txres@txJust        = "CenterRight"

  txres2               = True
  txres2@txFont        = "helvetica" 
  txres2@txFontHeightF = 0.008
  txres2@txJust        = "BottomLeft"

;----------------------------------------------------------------------
; The plotting section.
;----------------------------------------------------------------------
;
; Reading the data files and placing all the tracks on the plot

; read track files
filename   = systemfunc("cat " + Files)
Label   = systemfunc("cat " + Files)

print(filename)
print(Label)

;Add header at top
  txt0 = create "MainPlotTitle" textItemClass wks
    "txString"              : track
    "txFontHeightF"         : 0.018
    "txBackgroundFillColor" : "White"
    "txPerimOn"             : True
    "txPerimColor"          : "Black"
    "txFont"                : "helvetica"
  end create
  anno = NhlAddAnnotation(map,txt0)
  setvalues anno
    "amZone"           : 0
    "amSide"           : "Top"
    "amJust"           : "TopLeft"
    "amParallelPosF"   : -0.5
    "amOrthogonalPosF" : 0.5
    "amResizeNotify"   : False
  end setvalues

 ;Add INFO in a box on the right
 ;bottomstring = model + " Runs:" + cr 
  bottomstring = "         "
  do iNumFil=0,dimsizes(filename)-1
    iFor = iNumFil + 1
    bottomstring = bottomstring + cr + "  " + iFor + " - " + Label(iNumFil)
  end do
  bottomstring = bottomstring + cr + "  ---  Best Track"
  txt1 = create "TIMEInfo" textItemClass wks
    "txString"              : bottomstring
    "txFontHeightF"         : 0.012
    "txBackgroundFillColor" : "White"
    "txPerimOn"             : True
    "txPerimColor"          : "Black"
    "txFont"                : "helvetica"
  end create
  anno = NhlAddAnnotation(map,txt1)
  setvalues anno
    "amZone"           : 0
    "amSide"           : "Top"
    "amJust"           : "TopRight"
    "amParallelPosF"   : 0.49
    "amOrthogonalPosF" : 0.49
    "amResizeNotify"   : False
  end setvalues

; Draw map and then add lines and symbols
  draw(map)

; how often do we plot the information

  interval = 6
  ii  = 12                       ; plot label every 24 hours
  iii = 6                        ; plot symbol every 6 hours
  iil = floattoint(6/interval)   ; draw line every 3 hours

;#######################################################################
;#######################################################################

do iNumFil=0,dimsizes(filename)-1

if(.not.fileexists(filename(iNumFil)))then
    print("file skipped: "+filename(iNumFil))
    continue
end if

if ( NowReading .eq. "ADECK" ) then
 
  ; Read lat/lon speed and pressure
   print("reading "+filename(iNumFil))
   adeck = read_atcf(filename(iNumFil))

 

  ; we know this data is in kts (need to check)
  DataType = "kts"
  cat1 = 64.0
  cat2 = 84.0
  cat3 = 97.0
  cat4 = 114.0
  cat5 = 135.0

end if

print(adeck@vmax)


;+++++++++ STORM +++++++++++++

  lnres@iNumFil  = iNumFil
  lnres@filename = filename(iNumFil)
  
; Add line 
  lnres@gsLineThicknessF = 7.0
  lnres@gsLineColor    = 2 + iNumFil
  do i=0,dimsizes(adeck@vmax)-iil-1,iil
    if ( adeck@vmax(i) .ne. -1.0 .and. adeck@vmax(i+iil) .ne. -1.0 ) then
      gsn_polyline(wks,map,(/adeck@lon(i),adeck@lon(i+iil)/),(/adeck@lat(i),adeck@lat(i+iil)/),lnres)
    end if
  end do

; Add Symbols over line
  pmres@gsMarkerColor = 2 + iNumFil
  do i=0,dimsizes(adeck@vmax)-1
    if ( adeck@vmax(i) .ne. -1.0 .and.mod(toint(adeck@hh(i)),iii).eq.0 ) then
      pmres@gsMarkerSizeF = 0.007
      pmres@gsMarkerIndex = 16
      gsn_polymarker(wks,map,adeck@lon(i),adeck@lat(i),pmres)
    end if
  end do


; Number label at end of track
  txres              := True
  txres@txFont        = "helvetica" 
  txres@txFontColor   = "black"
  txres@txFontHeightF = 0.009  
  txres@txPerimOn     = True   
  txres@txBackgroundFillColor = "White"
  txres@txJust    = "BottomLeft" 
; Number label can be earlier if track goes offscreen.
  itest = max(ind(adeck@vmax.ne.-1.0.and.adeck@lon.lt.max_lon))
  itest2 = max(ind(adeck@vmax.ne.-1.0.and.adeck@lat.lt.max_lat))
  itest = min((/itest,itest2/))

  ; Just put number at end of track	
  gsn_text(wks,map,iNumFil+1,adeck@lon(itest),adeck@lat(itest),txres)
  ; Put track name at end of track (number and init time)
  ;gsn_text(wks,map,Label(iNumFil),adeck@lon(itest),adeck@lat(itest),txres)
  

; forecast hour label [optional]
  txres2@txPerimOn   = False
  txres2@txFontColor = pmres@gsMarkerColor
  ; Label forecast at first point
  gsn_text(wks,map,"  "+adeck@dd(0)+"/"+adeck@hh(0),adeck@lon(0),adeck@lat(0),txres2)
  do i=0,dimsizes(adeck@vmax)-1
    ; skip 50 and 64 kt lines
    if ( adeck@rad(i) .le. 34 .and. mod(toint(adeck@fhr(i)),ii).eq.0) then
      ;gsn_text(wks,map,"  "+adeck@fhr(i),adeck@lon(i),adeck@lat(i),txres)
    end if
  end do


end do

;+++++++++++++++++++++++++++++++
;BestTrack
;
; Read lat/lon speed and pressure
    bdeck = read_atcf(btFile)

; Read Time stamps
   btdate = "  " + bdeck@dd + "/" + bdeck@hh
;   btcat = stringtoint(systemfunc("cut -c49-51 " + btFile))
;
   lnres@gsLineThicknessF = 8.0
   lnres@gsLineDashPattern = 0
   do i=0,dimsizes(bdeck@lat)-2
      lnres@gsLineColor    = "Black"
      gsn_polyline(wks,map,(/bdeck@lon(i),bdeck@lon(i+1)/),(/bdeck@lat(i),bdeck@lat(i+1)/),lnres)
   end do

; Add Symbols over line
  do i=0,dimsizes(bdeck@lat)-1
    if ( bdeck@vmax(i) .ne. -1.0.and.mod(toint(bdeck@hh(i)),iii).eq.0 ) then
      pmres@gsMarkerColor = 1
      pmres@gsMarkerSizeF = 0.05
      pmres@gsMarkerIndex = 1
      gsn_polymarker(wks,map,bdeck@lon(i),bdeck@lat(i),pmres)
    end if
  end do

; day/hh label
  txres@txPerimOn     = False
  txres@txFontColor   = "black"
  delete(txres@txBackgroundFillColor)
  do i=0,dimsizes(bdeck@vmax)-1
    if ( bdeck@rad(i) .le. 34 .and. mod(toint(bdeck@hh(i)),ii).eq.0) then
      gsn_text(wks,map,btdate(i),bdeck@lon(i),bdeck@lat(i),txres)
    end if
  end do
  frame(wks)

end
