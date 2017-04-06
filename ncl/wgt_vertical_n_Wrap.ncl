; copied from Dennis Shea's beta ncl 6.4.0. contributed.ncl 
; see email exchange Sep 28, 2016

undef("wgt_vertical_n_Wrap")
function wgt_vertical_n_Wrap (X:numeric, dp:numeric, iopt:integer, lev_dim[1]:integer)
; 
; Perform weighted vertical average (integral) or sum
; 
; Requirement: X must be in the following order: ([time,]lev,lat,lon)
;
; Nomenclature:
; X         - array to be integrated. No missing data allowed
; dp        - pressure thickness computed by "dpres_hybrid_ccm" or "dpres_plevel"
;             Must be the same size/shape as X
;             No missing data allowed.
; iopt      - =0 weighted vertical average
;             =1 weighted vertical sum
;             =2 weighted vertical sum, vertical avg
; lev_dim   - level dimension
;             lev_dim = 0                            ; (lev), (0); (time,lev),  (0,1) 
;                                                    ; (lev,lat,lon),  (0,1,2) 
;             lev_dim = 1                            ; (time,lev,lat,lon), (0,1,2,3)
;             lev_dim = 2                            ; (case,time,lev,lat,lon), (01,2,3,4)
;+++++++++++++++++++++++
; Usage for hybrid levels
;        f = addfile("....", "r")
;        hyai = f->hyai
;        hybi = f->hybi
;        p0   = f->P0                               ; p0=1000 or p0=100000
;        ps   = f->PS
;    
;        dp   = dpres_hybrid_ccm (ps,p0,hyai,hybi)  ; Pa [kg/(m s2)]
;--------------------
; Usage for pressure levels
;        f   = addfile("....", "r")
;        lev = f->lev  ; (/  1,  2,  3,  5,   7, 10, 20, 30, \   ; hPa 
;                           50, 70,100,150, 200,250,300,400, \
;                          500,600,700,775, 850,925,1000 /)
;                      ; uniys of lev and psfc must match
;        psfc= f->PS   ; PA         (time,lat,lon)
;        lev = lev*100 ; make PA to match psfc       
;        lev@units = "PA"
;
;        ptop= 0       ; integrate 0==>psfc at each grid point
;
;                      ; dp(klev,nlat,mlon) or dp(ntim,klev,nlat,mlon)
;        dp  = dpres_plevel(lev, psfc, ptop, 0)     ; Pa [kg/(m s2)]
;--------------------
; Use the 'dp' from above                           ; (  0 , 1 , 2 , 3 )
;        t    = f->T                                ; (time,lev,lat,lon)
;        xvi  = wgt_vert_n(t, dp,  0, 1)

local dimX, dimDP, rankX, Xdp, vsum, wsum, vavg
begin

  dimX  = dimsizes( X )
  dimDP = dimsizes( dp )
  rankX = dimsizes( dimX )

  if (.not.all(dimDP.eq.dimX) ) then  ; error check
      print("wgt_vertical_n: dimension sizes are not equal")
      print("wgt_vertical_n:  dimX="+dimX)
      print("wgt_vertical_n: dimDP="+dimsizes(dp) )
      exit
  end if

  if (isatt(X,"_FillValue") .and. any(ismissing(X)) ) then  ; error check
      print("wgt_vertical_n: No _FillValue allowed")
      print("wgt_vertical_n: X: nFill="+num(ismissing(X)))
      exit
  end if

;;if (isatt(dp,"_FillValue") .and. any(ismissing(dp)) ) then  ; error check
;;    print("wgt_vertical_n: No _FillValue allowed")
;;    print("wgt_vertical_n: dp: nFill="+num(ismissing(dp)))
;;    exit
;;end if

  Xdp  = X*dp                                ; [? kg/(m s2)]   (temporary variable)
  ;copy_VarCoords(X, Xdp)
  copy_VarMeta(X, Xdp) ; Dennis didn't copy metadata, just coords. why?

  vsum = dim_sum_n_Wrap( Xdp, lev_dim )      ; sum vertically [ie integrate]
  if (iopt.eq.1) then
      return(vsum)
  end if

  wsum = dim_sum_n_Wrap( dp , lev_dim )      ;  "      " 
  if (any(wsum.eq.0)) then
      if (.not.isatt(wsum,"_FillValue")) then
          wsum@_FillValue = default_fillvalue(typeof(wsum))
      end if
      wsum = where(wsum.eq.0, wsum@_FillValue, wsum)   ; avoid division by 0
  end if
      
  vavg = vsum/wsum                           ; one less dimension (no vertical dim)
  copy_VarMeta(vsum, vavg) 
  vavg@NCL_op = "Weighted Vertical Average"

  vsum@NCL_op = "Weighted Vertical Sum"
  wsum@NCL_op = "Summed Weights"
  ; copy attributes about steering flow
  if(isatt(dp,"steering_flow_bounds"))then
    vavg@steering_flow_bounds = dp@steering_flow_bounds
    vsum@steering_flow_bounds = dp@steering_flow_bounds
    wsum@steering_flow_bounds = dp@steering_flow_bounds
  end if
  if(isatt(dp,"original_lev"))then
    vavg@original_lev = dp@original_lev
    vsum@original_lev = dp@original_lev
    wsum@original_lev = dp@original_lev
  end if

  if (iopt.eq.0) then
      return(vavg)
  end if

  return([/ vavg, vsum, wsum /] )    ; iopt=2
end
;--------------------------------------------------------

