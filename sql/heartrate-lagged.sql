set search_path to mimiciii, public;

-- CREATE TYPE result AS (hr double, hr_1h double, hr_5h double, 
--                       hr_mean double, hr_min double, hr_max double);

with stg as (
    select ie.icustay_id, ie.subject_id
         , date_trunc('hour', charttime) as timestamp
    --    , di.label
    --    , charttime
    --    , de.itemid
    --    , de.value
        , de.valuenum
    from icustays ie
    inner join chartevents de
      on ie.icustay_id = de.icustay_id 
    inner join d_items di
    on de.itemid = di.itemid
    where ie.hadm_id = 103075
    and de.itemid = 211
    group by
    	date_trunc('hour', charttime) -- , trunc(EXTRACT(hour from TIMESTAMP) / 6)
    	, ie.icustay_id, ie.subject_id, de.valuenum
),

raw as (
	select stg.timestamp, avg(stg.valuenum) as hr 
    from stg
    group by stg.timestamp
)

select raw.timestamp
, raw.hr
, lag(raw.hr, 1) over (order by raw.timestamp) as hr_1h
, lag(raw.hr, 5) over (order by raw.timestamp) as hr_5h
, avg(raw.hr) OVER (ORDER BY raw.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_mean_6h
, min(raw.hr) OVER (ORDER BY raw.timestamp
 	rows between 6 preceding
  	and current row) as hr_filter_min_6h
, max(raw.hr) OVER (ORDER BY raw.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_max_6h
, public.median(raw.hr) OVER (ORDER BY raw.timestamp
  	rows between 6 preceding
  	and current row) as hr_filter_median_6h
from raw
-- order by raw.timestamp