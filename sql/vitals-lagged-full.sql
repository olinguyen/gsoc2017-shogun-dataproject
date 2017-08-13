-- This query pivots the time series vital signs for the first 24 hours of a patient's stay
-- Vital signs include heart rate, blood pressure, respiration rate, and temperature

set search_path to mimiciii;

WITH stg AS (
    SELECT pvt.subject_id, pvt.hadm_id, pvt.icustay_id, pvt.timestamp

    -- Easier names
  , case when VitalID = 1 then valuenum else null end as HeartRate
  , case when VitalID = 2 then valuenum else null end as SysBP
  , case when VitalID = 3 then valuenum else null end as DiasBP
  , case when VitalID = 4 then valuenum else null end as MeanBP
  , case when VitalID = 5 then valuenum else null end as RespRate
  , case when VitalID = 6 then valuenum else null end as TempC
  , case when VitalID = 7 then valuenum else null end as SpO2
    
    FROM  (
      select ie.subject_id, ie.hadm_id, ie.icustay_id
      , date_trunc('hour', ce.charttime) as timestamp
      , case
        when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then 1 -- HeartRate
    	when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then 2 -- SysBP
        when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then 3 -- DiasBP
        when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then 4 -- MeanBP
        when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then 5 -- RespRate
        when itemid in (223761,678) and valuenum > 70 and valuenum < 120  then 6 -- TempF, converted to degC in valuenum call
        when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then 6 -- TempC
        when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then 7 -- SpO2
        else null end as VitalID
          -- convert F to C
      , case when itemid in (223761,678) then (valuenum-32)/1.8 else valuenum end as valuenum

      from icustays ie
      left join chartevents ce
      on ie.subject_id = ce.subject_id and ie.hadm_id = ce.hadm_id and ie.icustay_id = ce.icustay_id
      and ce.charttime between ie.intime and ie.intime + interval '1' day
      -- exclude rows marked as error
      and ce.error IS DISTINCT FROM 1
      where ce.itemid in
      (
      -- HEART RATE
      211, --"Heart Rate"
      220045, --"Heart Rate"
          
    -- SYSTOLIC BLOOD PRESSURE
    51, 
    442, 
    455, 
    6701, 
    220179, 
    220050,

    -- DIASTOLIC BLOOD PRESSURE
    8368, 
    8440, 
    8441, 
    8555, 
    220180, 
    220051,

    -- MEAN BLOOD PRESSURE
    456, --"NBP Mean"
    52, --"Arterial BP Mean"
    6702, --	Arterial BP Mean #2
    443, --	Manual BP Mean(calc)
    220052, --"Arterial Blood Pressure mean"
    220181, --"Non Invasive Blood Pressure mean"
    225312, --"ART BP mean"

    -- RESPIRATORY RATE
    618,--	Respiratory Rate
    615,--	Resp Rate (Total)
    220210,--	Respiratory Rate
    224690, --	Respiratory Rate (Total)

    -- TEMP C
    223761,
    678,
    223762, 
    676,

    -- SpO2
    646, 
    220277
    )
    ) pvt
    group by pvt.subject_id, pvt.hadm_id, pvt.icustay_id, pvt.timestamp, pvt.vitalid, pvt.valuenum
    order by pvt.subject_id, pvt.hadm_id, pvt.icustay_id
),

agg as (
	select stg.timestamp, stg.subject_id, stg.hadm_id, stg.icustay_id
    , avg(stg.heartrate) as heartrate
   	, avg(stg.sysbp) as sysbp
   	, avg(stg.diasbp) as diasbp
   	, avg(stg.meanbp) as meanbp
   	, avg(stg.resprate) as resprate
   	, avg(stg.tempc) as tempc
   	, avg(stg.spo2) as spo2
    
    from stg
    group by stg.timestamp, stg.icustay_id, stg.hadm_id, stg.subject_id
)

select agg.timestamp, agg.subject_id, agg.hadm_id, agg.icustay_id
-- heartrate
, agg.heartrate
, lag(agg.heartrate, 1) over (order by agg.timestamp) as hr_1h
, avg(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_mean_6h
, min(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_min_6h
, max(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_max_6h
, public.median(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_median_6h    
    
-- sysbp
, agg.sysbp
, lag(agg.sysbp, 1) over (order by agg.timestamp) as sysbp_1h
, avg(agg.sysbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as sysbp_mean_6h
, min(agg.sysbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as sysbp_min_6h
, max(agg.sysbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as sysbp_max_6h
, public.median(agg.sysbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as sysbp_median_6h    

-- diasbp
, agg.diasbp
, lag(agg.diasbp, 1) over (order by agg.timestamp) as diasbp_1h
, avg(agg.diasbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as diasbp_mean_6h
, min(agg.diasbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as diasbp_min_6h
, max(agg.diasbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as diasbp_max_6h
, public.median(agg.diasbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as diasbp_median_6h    

-- meanbp
, agg.meanbp
, lag(agg.meanbp, 1) over (order by agg.timestamp) as meanbp_1h
, avg(agg.meanbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as meanbp_mean_6h
, min(agg.meanbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as meanbp_min_6h
, max(agg.meanbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as meanbp_max_6h
, public.median(agg.meanbp) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as meanbp_median_6h    

-- resprate
, agg.resprate
, lag(agg.resprate, 1) over (order by agg.timestamp) as resprate_1h
, avg(agg.resprate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as resprate_mean_6h
, min(agg.resprate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as resprate_min_6h
, max(agg.resprate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as resprate_max_6h
, public.median(agg.resprate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as resprate_median_6h    

-- tempc
, agg.tempc
, lag(agg.tempc, 1) over (order by agg.timestamp) as tempc_1h
, avg(agg.tempc) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as tempc_mean_6h
, min(agg.tempc) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as tempc_min_6h
, max(agg.tempc) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as tempc_max_6h
, public.median(agg.tempc) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as tempc_median_6h    

-- spo2
, agg.spo2
, lag(agg.spo2, 1) over (order by agg.timestamp) as spo2_1h
, avg(agg.spo2) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as spo2_mean_6h
, min(agg.spo2) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as spo2_min_6h
, max(agg.spo2) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as spo2_max_6h
, public.median(agg.spo2) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as spo2_median_6h    

from agg;