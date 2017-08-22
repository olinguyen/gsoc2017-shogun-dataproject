set search_path to mimiciii;

-- Table #3: Services
with serv AS
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

-- Table #4: Clinical data + demographics
, co AS
(
SELECT icu.subject_id, icu.hadm_id, icu.icustay_id, first_careunit, admission_type
, icu.los as icu_los
, round((EXTRACT(EPOCH FROM (adm.dischtime-adm.admittime))/60/60/24) :: NUMERIC, 4) as hosp_los
, EXTRACT('epoch' from icu.intime - pat.dob) / 60.0 / 60.0 / 24.0 / 365.242 as age_icu_in
, icu.intime as icu_intime
, pat.gender
, pat.dod_hosp
, RANK() OVER (PARTITION BY icu.subject_id ORDER BY icu.intime) AS icustay_id_order
, hospital_expire_flag
, CASE WHEN pat.dod IS NOT NULL 
       AND pat.dod >= icu.intime - interval '6 hour'
       AND pat.dod <= icu.outtime + interval '6 hour' THEN 1 
       ELSE 0 END AS icu_expire_flag
, CASE WHEN pat.dod IS NOT NULL
    AND pat.dod < adm.admittime + interval '30' day THEN 1 
    ELSE 0 END as hospital30day_expire_flag
, CASE WHEN pat.dod IS NOT NULL
    AND pat.dod < adm.admittime + interval '1' year THEN 1 
    ELSE 0 END as hospital1year_expire_flag      
FROM icustays icu
INNER JOIN patients pat
  ON icu.subject_id = pat.subject_id
INNER JOIN admissions adm
ON adm.hadm_id = icu.hadm_id    
)

-- Table #5: Exclusions
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

SELECT 

-- vital signs for the first 24 hours of the icu stay
vital.*

-- vital.icustay_id, vital.subject_id, vital.hadm_id
-- , HeartRate
-- , DiasBP
-- , SysBP
-- , MeanBP
-- , RespRate
-- , TempC
-- , SpO2

-- demographic data
, co.age_icu_in, co.first_careunit, co.gender, co.admission_type
, hw.height_first, hw.weight_first
, EXTRACT('epoch' from vital.timestamp - co.icu_intime) / 60.0 / 60.0 / 24.0 / 365.242 as icu_los
-- outcomes
, co.hospital_expire_flag, co.icu_expire_flag
, co.hosp_los, co.icu_los, co.icustay_id_order
, co.dod_hosp
, CASE 
    WHEN vital.timestamp >= co.dod_hosp THEN 1 
    ELSE 0 END 
    AS dead
, CASE 
    WHEN vital.timestamp + interval '1' day >= co.dod_hosp THEN 1 
    ELSE 0 END 
    AS dead_in_1d
, CASE 
    WHEN vital.timestamp + interval '7' day >= co.dod_hosp THEN 1 
    ELSE 0 END 
    AS dead_in_7d
, CASE 
    WHEN vital.timestamp + interval '30' day >= co.dod_hosp THEN 1 
    ELSE 0 END 
    AS dead_in_30d

-- exclusions
, excl.exclusion_los, excl.exclusion_age
, excl.exclusion_first_stay, excl.exclusion_surgical

FROM mimiciii_dev.vitalsfirstday_timeseries vital
LEFT JOIN mimiciii_dev.labsfirstday lab
  ON vital.icustay_id = lab.icustay_id
LEFT JOIN mimiciii_dev.gcsfirstday gcs
  ON vital.icustay_id = gcs.icustay_id
LEFT JOIN mimiciii_dev.uofirstday uo
  ON vital.icustay_id = uo.icustay_id
LEFT JOIN mimiciii_dev.ventfirstday vent
  ON vital.icustay_id = vent.icustay_id
left join co
  ON vital.icustay_id = co.icustay_id
left join public.heightweight hw
  ON vital.icustay_id = hw.icustay_id
left join excl
  on vital.icustay_id = excl.icustay_id;
