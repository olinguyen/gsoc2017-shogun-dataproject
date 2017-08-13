set search_path to mimiciii;

-- Staging table #1: CHARTEVENTS
with ce_stg as
(
  select ie.subject_id, ie.hadm_id, ie.icustay_id
  , case
      when itemid in (211,220045) and chart.valuenum > 0 and chart.valuenum < 300 then 1 -- HeartRate
      when itemid in (456,52,6702,443,220052,220181,225312) and chart.valuenum > 0 and chart.valuenum < 300 then 4 -- MeanBP
      when itemid in (615,618,220210,224690) and chart.valuenum > 0 and chart.valuenum < 70 then 5 -- RespRate
      else null end as vitalid
  , case
      when chart.itemid = any (ARRAY[223761, 678]) then (chart.valuenum - 32::double precision) / 1.8::double precision
      else chart.valuenum end as valuenum

  from icustays ie
  left join chartevents chart
    on ie.subject_id = chart.subject_id and ie.hadm_id = chart.hadm_id and ie.icustay_id = chart.icustay_id
    and chart.charttime >= ie.intime and chart.charttime <= (ie.intime + '1 day'::interval day)
    and chart.error is distinct from 1
    where chart.itemid = any
    (array[
    -- HEART RATE
    211, --"Heart Rate"
    220045, --"Heart Rate"

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
    224690 --	Respiratory Rate (Total)

    ])
)

-- Aggregate table #1: CHARTEVENTS
, ce as
(
  SELECT ce_stg.subject_id, ce_stg.hadm_id, ce_stg.icustay_id
  , min(case when VitalID = 1 then valuenum else null end) as HeartRate_Min
  , max(case when VitalID = 1 then valuenum else null end) as HeartRate_Max
  , avg(case when VitalID = 1 then valuenum else null end) as HeartRate_Mean
  , min(case when VitalID = 4 then valuenum else null end) as MeanBP_Min
  , max(case when VitalID = 4 then valuenum else null end) as MeanBP_Max
  , avg(case when VitalID = 4 then valuenum else null end) as MeanBP_Mean
  , min(case when VitalID = 5 then valuenum else null end) as RespRate_Min
  , max(case when VitalID = 5 then valuenum else null end) as RespRate_Max
  , avg(case when VitalID = 5 then valuenum else null end) as RespRate_Mean

  FROM ce_stg
  group by ce_stg.subject_id, ce_stg.hadm_id, ce_stg.icustay_id
  order by ce_stg.subject_id, ce_stg.hadm_id, ce_stg.icustay_id
   
)

-- Table #2: Clinical data + demographics
, co AS
(
SELECT icu.subject_id, icu.hadm_id, icu.icustay_id, first_careunit
, icu.los as icu_los
, round((EXTRACT(EPOCH FROM (adm.dischtime-adm.admittime))/60/60/24) :: NUMERIC, 4) as hosp_los
, EXTRACT('epoch' from icu.intime - pat.dob) / 60.0 / 60.0 / 24.0 / 365.242 as age_icu_in
, pat.gender
, RANK() OVER (PARTITION BY icu.subject_id ORDER BY icu.intime) AS icustay_id_order
, hospital_expire_flag
, CASE WHEN pat.dod IS NOT NULL 
       AND pat.dod >= icu.intime - interval '6 hour'
       AND pat.dod <= icu.outtime + interval '6 hour' THEN 1 
       ELSE 0 END AS icu_expire_flag
FROM icustays icu
INNER JOIN patients pat
  ON icu.subject_id = pat.subject_id
INNER JOIN admissions adm
ON adm.hadm_id = icu.hadm_id    
)

-- Table #3: Services
, serv AS
(
SELECT icu.hadm_id, icu.icustay_id, se.curr_service
, CASE
    WHEN curr_service like '%SURG' then 1
    WHEN curr_service = 'ORTHO' then 1
    ELSE 0 END
  as surgical
, RANK() OVER (PARTITION BY icu.hadm_id ORDER BY se.transfertime DESC) as rank
FROM icustays icu
LEFT JOIN services se
 ON icu.hadm_id = se.hadm_id
AND se.transfertime < icu.intime + interval '12' hour
)
-- Table #4: Exclusions
, excl AS
(
SELECT
  co.subject_id, co.hadm_id, co.icustay_id, co.icu_los, co.hosp_los
  , co.age_icu_in
  , co.gender
  , co.icustay_id_order
  , serv.curr_service
  , co.first_careunit
  , co.hospital_expire_flag
  , co.icu_expire_flag
  , CASE
        WHEN co.icu_los < 1 then 1
    ELSE 0 END
    AS exclusion_los
  , CASE
        WHEN co.age_icu_in < 16 then 1
    ELSE 0 END
    AS exclusion_age
  , CASE 
        WHEN co.icustay_id_order != 1 THEN 1
    ELSE 0 END 
    AS exclusion_first_stay
  , CASE
        WHEN serv.surgical = 1 THEN 1
    ELSE 0 END
    as exclusion_surgical
FROM co
LEFT JOIN serv
  ON  co.icustay_id = serv.icustay_id
  AND serv.rank = 1
)

SELECT ex.subject_id, ex.hadm_id, ex.icustay_id, ex.age_icu_in, ex.first_careunit, ex.gender, 
    ex.hospital_expire_flag, ex.icu_expire_flag, ex.hosp_los, ex.icu_los, ex.icustay_id_order

, ce.HeartRate_Min
, ce.HeartRate_Max
, ce.MeanBP_Min
, ce.MeanBP_Max
, ce.RespRate_Min
, ce.RespRate_Max

FROM excl ex
left join ce
  on ex.hadm_id = ce.hadm_id
WHERE exclusion_los = 0
AND exclusion_age = 0
AND exclusion_first_stay = 0;

