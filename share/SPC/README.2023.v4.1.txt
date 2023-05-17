README.TXT file for SPC TCTOR DATABASE V4.1 [2023 Version, Data thru 2022]

Roger Edwards
Storm Prediction Center
roger.edwards@noaa.gov

E-mail the author (roger.edwards@noaa.gov) for the latest version or download from 
https://www.spc.noaa.gov/publications/edwards/tctor.xls
with this file updated at 
https://www.spc.noaa.gov/publications/edwards/readme.txt

1. BACKGROUND (adapted from Edwards 2010a SLS Conference Preprint -- TCTOR paper):

a. Justification and Tornado-record Characteristics

Given the concerns with the tornado data overall, and by extension, with TC tornado records, a more focused, updated and consistent basis of analysis should be used than those available in existing literature.  This is in order to:  a) ameliorate impacts of systematic ìshocksî to the data record (Thorne and Vose 2010), such as that resulting from NWS modernization in the early 1990s, and b) still offer a large sample (see Doswell 2007 for thorough discussion on sample size issues with tornado data).  To those ends, that study analyzed TC tornado records spanning 1995ñ2009 (mapped in Fig. 2). The chosen period corresponds essentially to the full national deployment of WSR-88D units, and as such, is entirely within the framework of modern warning and verification practices based thereon.  

Each potential TC tornado record in the conterminous U.S. was examined individually, by comparison with surface and upper air maps, archived satellite photos and/or imagery derived from archived NEXRAD Level II data (Kelleher et al. 2007), to determine its presence within the circulation envelope of either a classified or remnant tropical cyclone.  Qualifying events were segregated from the nationwide Storm Prediction Center (SPC) one-tornado (ONETOR) database and assigned to their respective TCs by name.  TC tornado records initially retained all information from the parent ONETOR database (e.g., time, date, states, latitude/longitudes for path ends, EF rating, casualties, monetary damage estimates, etc.).  A ìsmoothî TC-tornado dataset (TCTOR) was compiled, expunging categorical redundancies (e.g., multiple columns specifying the same date and time), any ONETOR categories impertinent to this study (e.g., county FIPS numbers and a useless constant ì3î that denotes the CST time zone already given), as well as incorporating metric and UTC unit equivalents.

During the conversion of NCDC segmented data to ONETOR, intrastate county segments are stitched together to form whole-tornado tracks.  However, a state border-crossing tornado in ONETOR still is parsed into one segment per state, albeit with a duplicate entry number so the state-segments still can be plotted as a single track with mapping software.  In TCTOR, all such events are combined into a single TCTOR path entry with two states listed (e.g., GA-SC in the ìStateî column). 

b. Incorporation of TC Information

National Hurricane Center (NHC) best-track records (Hurricane Data, a.k.a. HURDAT) then were examined for each tornado event, from which the most recent 6-hourly central pressure and wind intensity were applied to each tornado.  Using those wind maxima (for classified systems), tornadoes were binned according to their correspondence with a tropical depression (TD), tropical storm (TS), hurricane (H), or a combination of all non-tropical and post-classification categories (N).  An N may include either official extratropical classifications, a change to subtropical (as with Allison of 2001), or as with TC Erin in 2007, a remnant low (Brennan et al. 2009, Monteverdi and Edwards 2010).  Linear interpolation between 6-hourly HURDAT center positions yielded a cyclone-center estimate at each tornado time.

The distance D from this interpolated TC center to the starting position of each tornado then was computed across a great-circle surface arc, in a variation of the spherical law of cosines (e.g., Sinnott 1984) that uses latitude (lat) and longitude (lon) in radians, as follows:

D = re * ( cos-1 { [sin(latTOR) * sin(latTC)] +   
[cos (latTOR) * cos(latTC) *                            (1)
 cos(lonTOR-lonTC)] } )    

where re is the mean radius of earth.  The subscripts TOR and TC signify tornado and TC-center positions respectively, neglecting any error at such relatively small radial angles that might arise from the centrifugal difference between polar and equatorial re.  Cartesian bearing of reports from TC center was included in TCTOR, to foment analyses of cyclone-relative tornadic traits.
 
The most recent 6-hourly TC classification (hurricane, tropical storm or tropical depression), central pressure and max wind also were logged for each tornado.  For TC-remnant tornadoes occurring post-HURDAT, the low location, pressure, and max wind were estimated subjectively from surface analyses, while the system also was assigned a post-classification category N (not classified as tropical cyclone).  For numerical sorting and ranking purposes, TC classifications were assigned as in the column-by-column table below. 

Records in TCTOR do include inland TC remnants interacting with low-level baroclinic zones, as long as: a) a closed surface low can be identified; and b) upper air data at the nearest 12-hourly synoptic times (0000 and 1200 UTC) indicate warm-core characteristics in the mid-troposphere (i.e., 700-500 hPa).  Records also are included from any tornadic TCs that failed to make U.S. landfall (e.g., recurving just offshore from the Carolinas or Florida Keys, or entering northern Mexico with tornadoes in Texas).  

Where NHC classifications had been discontinued, yet TC remnants still were apparent, the nearest hourís surface data were analyzed to estimate location of the pressure low--which, for this dataset, corresponded within analytic scale to the cyclone center derived from drawing streamlines except in the late stages of inland frontal interaction.  Each TC-related datum was incorporated into TCTOR alongside the corresponding tornado information.  

c. Caveats and Sources of Error

Several sources of potential error or uncertainty exist in TCTOR, as in ONETOR at large, that likely are nonlinear and certainly are not readily quantifiable, with the addition of some from HURDAT as well.  Position errors of tornadoes, in an absolute sense, may arise from either: a) uncorroborated location estimates provided to NWS, especially for non-damaging events or weak tornadoes not causing damage detectable above that from the TC; or b) the inherent imprecision of the location reporting and translation convention in Storm Data, whereby azimuth and range (in miles) from a town typically is logged, then converted to latitude and longitude out to two decimal places (mainly older data).  Wind damage misclassified as tornadoes, at the local level, cannot be ruled out in isolated instances.  At least one such event already has been discovered and removed from TCTOR post facto; others probably exist to an unknown (but likely very low-percentage) extent.

Linear interpolation of 6-hourly center fixes becomes less reliable where rapid changes in translational motion occur between them.  Sharp translational path accelerations, decelerations or curvatures within temporal bins are possible, but uncommon, and introduce some potential error on calculations of tornado distance and direction from center.  So do any temporal imprecisions in tornado reporting.  In fact, a marked tendency exists -- e.g., 64% of TCTOR records from 1995-2008 -- for times in whole minutes to end in the digits 0 or 5.  In the real atmosphere, no physical basis is apparent for any amount >20% of such timing.  HURDAT records, meanwhile, truncate TC center fixes to 10**-1 degree of latitude and longitude.  Inland center-fixes for decaying systems, particularly those of less than TD strength or located between relatively sparse surface observations, also may be subject to the same precision uncertainties that afflict any subjective analysis of a lowís location.  Therefore, TC center-relative tornado positions given in TCTOR should not be interpreted too precisely on an individual basis, spatially or temporally, but instead assessed with respect to relative characteristics and broader, TC-scale tendencies. Previous studies incorporating tornado positions relative to TC positions also are encumbered with such uncertainties, whether or not explicitly mentioned therein, simply by virtue of the imprecisions intrinsic to the ONETOR and HURDAT data.  

The primary difference with TCTOR, aside from the decadal domain, is in the individually-assessed, "manual" technique for selecting TCTOR events.  While time-intensive, this method is believed to offer the most accurate possible record as compared to existing TC-tornado climatologies.  This is because TCTOR logs events without regard to fixed radii from TC center, inland extent, temporal cutoffs before or after landfall, or other such arbitrary and readily automatable thresholds that either may: a) exclude bonafide TC tornadoes outside the spatial cut-offs, or b) include somewhat proximal but non-TC tornadoes unnecessarily.  Subjective analysis is subjective by definition, and a few fringe events for inland-decay stages may be open to argument as to whether they fall under the cyclone envelope.  Such events constitute <<1% of the data. 

TCTOR is flexible, in that it will grow with time and be open to evidence-based revision.  The author intends to update TCTOR on an annual basis as HURDAT and ONETOR data become available for the previous hurricane seasonís activity.  Additionally, TCTOR is available online for research and independent analysis, and may be amended on a post-facto basis as any errors are discovered, new information arrives and/or additional analyses are performed by other researchers on any historical TC tornadoes therein.  Such adjustments made to variables common to the two datasets (i.e., occurrence time, location, path width, etc.) will be passed to corresponding ONETOR management for consistency. 
  
Since any entry in TCTOR is open to revision, given sufficient evidence, any analyses derived from the dataset should be considered ìbest availableî at the time, and potentially subject to change as well.  Some changes may occur in the future in the way that tornado data are recorded overall, such as addition of decimal places to latitudes and longitudes for greater spatial precision, or greater texturing of path and damage information (Edwards et al. 2013 -- BAMS article on "Tornado Intensity Estimation").

3.  FORMAT

Dataset is in MS Excel format, which can be saved as CSV from within MS Word for ready ingestion and analysis by other software.  Columns (L-R) in first (Full List) tab are as follows:

A. Year

B. Month (UTC)

C. Date (UTC)

D. Time (UTC)

E. Month (CST -- the time zone for SPC ONETOR source data)

F. Date (CST)

G. CST Time

H. State(s).  Another difference with TCTOR:  State-crossing tornadoes are combined into one row here.

I. Yearly tornado tracking number by state.  Discontinued in 2008 except for recurrence 2010-11.

J. F or EF Scale damage rating.  EF took effect for 2007 TC season and since.

K. Number Injured

L. Number Killed

M. Damage code (estimated property loss information).  Prior to 1996 this is a categorization of tornado damage by dollar amount (0 or blank-unknown; 1<$50, 2=$50-$500, 3=$500-$5,000, 4=$5,000-$50,000; 5=$50,000-$500,000, 6=$500,000-$5,000,000, 7=$5,000,000-$50,000,000, 8=$50,000,000-$500,000,000, 9=$5000,000,000.) From 1996, this is tornado property damage in millions of dollars. Note: this may change to whole dollar amounts in the future. Entry of 0 does not mean $0, but also could stand for unreported damage total.

N. Crop code: estimated crop loss in millions of dollars (started in 2007). Entry of 0 does not mean $0.

O. Starting latitude of tornado, decimal degrees.

P. Starting longitude of tornado.

Q. Ending latitude of tornado.

R. Ending Latitude of tornado.

S. Path Length (mi)

T. Path Length (km)

U. Path width (yd)

V. Path width (m)

W. Number of states affected.  Shading in segment columns denotes state border crossers combined from ONETOR

X. DPI (unitless, from Thompson and Vescio 1988).  This is not computed natively in ONETOR.  You get it as a free bonus!

Y. TC Name and Year 

Z. Last 6-hourly official "OFCL" TC latitude (from HURDAT if still classified, from surface analysis otherwise)

AA. Last 6-hourly official TC longitude (same sourcing)

AB. Last 6-hourly official max TC wind in kt (same sourcing)

AC. Last 6-hourly official minimum central pressure (same sourcing)

AD. Last 6-hourly TC category (Saffir-Simpson value) or N for Not classified/remnant low

AE. Category Code as follows:  5 = Major Hurricane, Category 5; 4 = Major Hurricane, Category 4; 3 = Major Hurricane, Category 3; 2 = Hurricane, Category 2; 1 = Hurricane, Category 1; 0 = Tropical (or Subtropical) Storm; -1 = Tropical Depression; -2 covers every other post-landfall category (extratropical, remnant low, no longer classified, etc.)

AF. Next 6-hourly TC latitude (from HURDAT if classified therein, otherwise from surface map)

AG. Next 6-hourly TC longitude (from HURDAT if classified therein, otherwise from surface map)

AH. Linearly interpolated TC position latitude (based on time elapsed since last 6-hourly)

AI. Linearly interpolated TC position longitude (based on time elapsed since last 6-hourly)

AJ. Cartesian (relative to true N) tornado bearing from center, in deg.

AK. Tornado distance from center (km)

AL. Tornadoes for each TC (column should be removed for re-sorting spreadsheet)

AM-AN. Year and tornadoes for each year (columns should be removed for re-sorting spreadsheet)

"By TC" and "By Year" tabs are self-explanatory.  

OTHER TABS:
"By Year and EF" is where I make those calculations and charts
"By TC" is self-explanatory.
"Worksheet" contains computational input columns and spherical-geometry steps used to compute TC-relative (true-north) tornado data for the Full List, and for the motion-relative framework.  This is included in discrete column-steps for scientific reproducibility's sake. 

-------------------------------------------


4. NEWS (most recent first)

19 Apr 23:  With Ian HURDAT published, TCTOR is updated through 2022.  A couple inquiries into potential prior-year minor errors are pending, but will push this update out today and another in the future if/as needed.

18 Mar 23:  This tornado was updated based on radar reanalyses and submitted to both Storm Data and ONETOR, with worksheet AZRANs updated as needed:
* Harvey (29 Aug 17) time:  2200 changed to to 2242 UTC

These tornadoes were previously missing, now added, with all stats recalculated:
* Andrea (6 Jun 2013) 2107 UTC
* Bill (19 Jun 2015) 2057 UTC 

8 Jan 23:  A previously state-crossing path from Nate (8 Oct 17, 2137 UTC, SC-NC) had been corrected in Storm Data and ONETOR to two separate tornado paths, one entirely in each state.  This increases the count for Nate and 2017 by one, but not the respective state counts.  Worksheet AZRAN calculations and "By" tabs have been updated accordingly. Also updated path endpoint and miles for the GA-SC border-crossing Fay tornado (26 Aug 2008) at 1818 UTC.
Fixed latitude or longitude sign errors in the following endpoints: 
* Michael (10 Oct 18) 1840 UTC
* Fred (19 Aug 21) 118 UTC
* Ida (30 Aug 21) 1349 UTC

20 May 22:  TCTOR updated through 2021 from Storm Data.

28 Mar 22:  2020 ONETOR has been finalized and made available.  These previous TCTOR entries are reconciled to ONETOR as follows:
* Cristobal: 10 Jun 0133 UTC time changed to 0032 UTC.
* Isaias:  4 Aug 0940 UTC length update to 15.61 mi.  4 Aug 1255 UTC start point updated to 39.1049 -75.5001, path length now 35.78 mi.  4 Aug 0850 UTC (PA) start point now 40.0815 -74.9592, length now 20.77 mi.

21 Feb 22:  After consultation with local WCM, corrected:
* Harvey-17:  Previous 2234 UTC changed to 2227 UTC, new start location 30.1498 -92.1498, new end location 30.1545 -92.2250, new path length .6 mi.

27 Dec 21:  Made the following changes after consultation with local WCM:
* Michael-18:  First Michael tornado, time changed to 1840 UTC *and* starting lat/lon to 29.8036 -82.0906 *and* ending lat/lon to 30.0416 -82.0492.
* Irma-17:  11 Sep 0420 UTC changed to 0013 UTC.  11 Sep second 0625Z tornado lat/lons were reversed in Storm Data, ONETOR and TCTOR (cell was westward-moving).  Starting lat/lon updated slightly as well to 30.642, -81.467.  Ending corrected to 30.81, -81.57. 
* Andrea-13:  6 Jun 2107 UTC report reclassified as wind damage and deleted from TCTOR. 

18 Nov 21:  Corrected the following mostly time errors after consultation with local WCMs (with center-relative data recalculated for each):
* Cristobal-20: Two-minute error on start time of IL tornado, should be 2324 UTC.  
* Michael-18:  10 Oct 2235 UTC adjusted to 2247 UTC.  
* Florence-18:  16 Sep 1609 UTC changed to 0409 UTC and 15 Sep 1545 UTC changed to 1907 UTC.  
* Irma-17:  10 Sep 1140 UTC changed to 10 Sep 0017 UTC.  9 Sep 1320 UTC changed to 2301 UTC *and* starting lat/lon changed to 25.412 -80.377 *and ending lat/lon changed to 25.413 -80.41.  9 Sep 1210 UTC changed to 10 Sep 0013 UTC.
* Harvey-17:  30 Aug 0600 UTC adjusted to 0546 UTC, 31 Aug 2203 UTC adjusted to 2137 UTC.  
* Cindy-17:  Both 24 Jun 2017 events in NJ should be one hour earlier, now corrected to 1121 and 1127 UTC.
* Bill-15:  8 Jun 0909 UTC changed to 1009 UTC.
* Arthur-14:  4 Jul 0515 UTC changed to 0502 UTC *and* starting and ending lat/lons reversed.  4 Jul 0325 UTC in NC changed to 0359 UTC *and* starting lat/lon changed to 36.344 -76.964 *and* ending lat/lon changed to 36.343 -76.996.
* Andrea-13: 6 Jun 1205 UTC changed to 1157 UTC *and* starting lat/lon changed to 26.224 -80.4854 *and* ending lat/lon changed to 26.51 -80.387.  1849 UTC (FL) corrected to 0651 UTC; 1947 UTC entry corrected to 0750 UTC *and* starting lat/lon corrected to 27.598 -82.296 *and* length increased to 9.8 mi.

20 Aug 21:  Storm Data time-conversion error verified with local WCM for Emily-2017's tornado, corrected to 0855 CST/1455 UTC.  Center-relative data fixed as well with previous 6-hourly best-track position.

28 Jun 21:  Time-conversion errors fixed:  10 Jun 21 entry (Cristobal-20) should be 1833 CST/0033 UTC.  From Hanna-20:  26 Jul 21 0532 UTC should be 0832 UTC and 26 Jul 21 0910 UTC should be 1010 UTC (CST times are correct).  Recalculations to center-relative data.

1 Jun 21:  NHC's Laura and Zeta reports have posted with their 6-hourly center fixes, allowing TCTOR to be finished through 2020.  Thank you for your patience.

3 Oct 20:  Fixed the following minor time errors/inconsistencies, and recalculated worksheet data as needed:  Lee-11 (5 Sep, 1757 and 1911 UTC), Andrea-13 (6 Jun, 1849 UTC), Bill-15 (21 Jun, 0012 UTC), Irma-17 (11 Sep, 2145 UTC), Michael-18 (11 Oct, 2127 UTC).  Added decimal precision from Storm Data that was truncated in ONETOR, both to fix a minor rounding error and to clarify the starting and ending points weren't identical:  Harvey-17 (26 Aug, 1305 UTC).

17 Sep 20:  Removed former Column A (tracking number) due to errors, inconsistencies, non-necessity, and disuse.  Column A is now Year, which is necessary.  Separately, per consultation with local WCM, changed time of first Irene-11 tornado from 0112 to 0208 UTC (to fix Storm Data data-entry error).  Worksheet AZRAN also recalculated/re-entered.  This time change has been submitted for ONETOR.

22 Aug 20:  Fixed time typos:  Gordon-00 (17 Sep, now 2245 UTC), Isaac-12 (27 Aug, now 0709 UTC), all to match NCEI times.  Worksheet AZRANs also recalculated/re-entered. 

30 Apr 20:  Updated for 2019 data 

6 Jan 20:  Fixed HURDAT longitude typos with 3 entries for Irene-11 (28/0700, 0800, 0850 UTC). HURDAT "Next Lat/Lon" column update with recalculated AZRANs for Cindy-17 (21/1118 UTC).

4 Dec 19:  The final tornado previously listed for Rita-05 (26 Sep/1017 UTC) has been removed as a valid TCTOR entry.  The tornado occurred; however, upon reanalysis, it was declassified as a TC tornado, because Rita's remnant low had entirely dissipated as an identifiable surface low along a cold front by 09 UTC.  The previously associated low was well over 1000 km away:  a synoptic frontal low near Ottawa, ON, not related to Rita, which now has 97 associated tornadoes.

3 Dec 19:  Fixed HURDAT longitude typos with two entries for Bill-03 (1 Jul/0942 and 1029 UTC) and redid all worksheet/AZRAN calculations for tornadoes using those points; minor (0.2 deg) shift in HURDAT longitude for TC Rita tornado 26 Jul 2005/0242 UTC, with AZRANs recalculated. 

5 Jun 19:  Updated for 2018 data, NHC HURDAT was delayed into SPC spring severe season due to early-year govt. shutdown

11 Sep 18:  Fixed two typo-related AZRAN-from-center calculation errors for Harvey-17: entries #1355 and 1356 (27/903 UTC and 27/1515 UTC).

24 Aug 18:  Minor changes to ending lat/lon and start time of 26 Aug 2017 1000 UTC (was 0957) event in Harvey-17, per communication with local WCM.

16 Aug 18:  After time corrections were made to all of 2017 nationwide ONETOR due to conversion errors, tranferred those revised times for TC events (and recalculated positions vs. HURDAT) for all 2017 TCTOR entries.  Added revised event numbers from ONETOR as well. 

15 Aug 18:  Fixed time-conversion error on 2 Sep 16, 0912Z, 31.93, -81.03, TC Cindy

23 Apr 18:  Updated for 2017 data.  Combined previously segmented 2-state entry (#1478) for Fay-08.

15 Oct 17:  Corrected bad path length on 13 Aug 2004, 2340Z, lat/lon 29.2 -81, MH Charley, per communication with local WCM.

15 Jun 17:  Updated for 2016 data.

20 Jun 17:  Retroactively added the following 2015 tornado that was in ONETOR:  18 Jun 2015, 1830Z, 36.6765, -88.519, TC Bill.

19 Oct 16:  Retroactively added the following 2012 tornado that was in Storm Data but originally failed to reach ONETOR: 31 Aug., 1836Z, start lat/lon 39.1126/-90.4656, TC Isaac.  This has been submitted to be added to ONETOR.  Added separate, previously missing event that was in ONETOR:  19 Jun 2015, 1730Z, 38.5691/-88.8535, TC Bill. 
 
22 Mar 16: Corrected all ".2" and "1" path-width entries in Frances-04 to 75 yd per communication with local WCM. 

6 Feb 16: Changed erroneous "0" path widths in Frances (2004) to .2 as listed (but still likely erroneously) in Storm Data; investigating those with local WCM.  Added column for DPI (col. Y) in Full List tab.

26 Jan 16: Updated for 2015 data. 

17 Jul 15: Updated for 2014 data.

5 Jan 14: Updated for 2013 data.

4 Oct 13:  Updated for 2012 data.  

31 Mar 12:  Updated for 2011 data. 

11 Sep 11:  Updated for 2010 data.

16 Sep 10:  First pre-release version (v0.1) available for limited preliminary research (requests for corrections are out for obviously suspicious data imported from ONETOR, such as path lengths in 100s of miles). 

