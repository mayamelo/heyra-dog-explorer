with source as (
    select *
    from {{ ref('stg_dog_api_breeds') }}
),

final as (
    select
        breed_id,
        breed_name,
        breed_group,
        -- life span metrics
        life_span_min_yrs,
        life_span_max_yrs,
        round((life_span_min_yrs + life_span_max_yrs) / 2, 1) as life_span_avg_yrs,
        -- weight metrics (kg)
        safe_cast(split(weight_male_kg, '-')[safe_offset(0)] as float64)    as weight_male_min_kg,
        safe_cast(split(weight_male_kg, '-')[safe_offset(1)] as float64)    as weight_male_max_kg,
        safe_cast(split(weight_female_kg, '-')[safe_offset(0)] as float64)  as weight_female_min_kg,
        safe_cast(split(weight_female_kg, '-')[safe_offset(1)] as float64)  as weight_female_max_kg,
        -- weight metrics (lbs)
        safe_cast(split(weight_male_lbs, '-')[safe_offset(0)] as float64)   as weight_male_min_lbs,
        safe_cast(split(weight_male_lbs, '-')[safe_offset(1)] as float64)   as weight_male_max_lbs,
        safe_cast(split(weight_female_lbs, '-')[safe_offset(0)] as float64) as weight_female_min_lbs,
        safe_cast(split(weight_female_lbs, '-')[safe_offset(1)] as float64) as weight_female_max_lbs,
        -- size class
        case
        when safe_cast(split(weight_male_kg, '-')[safe_offset(1)] as float64) <= 10 then 'Small'
        when safe_cast(split(weight_male_kg, '-')[safe_offset(1)] as float64) <= 25 then 'Medium'
        when safe_cast(split(weight_male_kg, '-')[safe_offset(1)] as float64) <= 45 then 'Large'
        when safe_cast(split(weight_male_kg, '-')[safe_offset(1)] as float64) is null then 'Unknown'
        else 'Giant'
        end as size_class
    from source
    where life_span_min_yrs is not null
      and life_span_max_yrs is not null
)

select * from final
order by breed_id desc