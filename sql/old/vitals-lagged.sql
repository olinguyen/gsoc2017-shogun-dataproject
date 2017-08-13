-- This query pivots the vital signs for the first 24 hours of a patient's stay
-- Vital signs include heart rate, blood pressure, respiration rate, and temperature

set search_path to mimiciii;

WITH stg AS (
    SELECT pvt.subject_id, pvt.hadm_id, pvt.icustay_id, pvt.timestamp

    -- Easier names
    , case when VitalID = 1 then valuenum else null end as heartrate

    FROM  (
      select ie.subject_id, ie.hadm_id, ie.icustay_id
      , date_trunc('hour', ce.charttime) as timestamp
      , case
        when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then 1 -- HeartRate
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
      220045 --"Heart Rate"
      )
    ) pvt
    group by pvt.subject_id, pvt.hadm_id, pvt.icustay_id, pvt.timestamp, pvt.vitalid, pvt.valuenum
    order by pvt.subject_id, pvt.hadm_id, pvt.icustay_id
),

agg as (
	select stg.timestamp, avg(stg.heartrate) as heartrate,
    		stg.subject_id, stg.hadm_id, stg.icustay_id
    from stg
    group by stg.timestamp, stg.icustay_id, stg.hadm_id, stg.subject_id
)

select agg.timestamp, agg.subject_id, agg.hadm_id, agg.icustay_id
, agg.heartrate
, lag(agg.heartrate, 1) over (order by agg.timestamp) as hr_1h
, lag(agg.heartrate, 5) over (order by agg.timestamp) as hr_5h
, avg(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_mean_6h
, min(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_min_6h
, max(agg.heartrate) OVER (ORDER BY agg.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_max_6h   
from agg;  