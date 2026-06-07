with source as (
    select *
    from {{ source('bronze', 'dog_api_raw') }}
),

renamed as (
    select
        -- ids
        cast(id as string) as breed_id,
        name as breed_name,
        -- attributes
        breed_group,
        origin,
        temperament,
        bred_for,
        description,
        history,
        country_code,
        perfect_for,
        -- life span
        cast(
            split(regexp_replace(life_span, r'[^0-9\-]', ''), '-')[safe_offset(0)]
            as int64
        ) as life_span_min_yrs,
        cast(
            split(regexp_replace(life_span, r'[^0-9\-]', ''), '-')[safe_offset(1)]
            as int64
        ) as life_span_max_yrs,
        -- height metric (cm)
        case
            when height.metric like '%Male%'
            then trim(split(split(height.metric, ';')[safe_offset(0)], ':')[safe_offset(1)])
            else height.metric
        end as height_male_cm,
        case
            when height.metric like '%Female%'
            then trim(split(split(height.metric, ';')[safe_offset(1)], ':')[safe_offset(1)])
            else height.metric
        end as height_female_cm,
        -- height imperial (in)
        case
            when height.imperial like '%Male%'
            then trim(split(split(height.imperial, ';')[safe_offset(0)], ':')[safe_offset(1)])
            else height.imperial
        end as height_male_in,
        case
            when height.imperial like '%Female%'
            then trim(split(split(height.imperial, ';')[safe_offset(1)], ':')[safe_offset(1)])
            else height.imperial
        end as height_female_in,
        -- weight metric (kg)
        case
            when weight.metric like '%Male%'
            then trim(split(split(weight.metric, ';')[safe_offset(0)], ':')[safe_offset(1)])
            else weight.metric
        end as weight_male_kg,
        case
            when weight.metric like '%Female%'
            then trim(split(split(weight.metric, ';')[safe_offset(1)], ':')[safe_offset(1)])
            else weight.metric
        end as weight_female_kg,
        -- weight imperial (lbs)
        case
            when weight.imperial like '%Male%'
            then trim(split(split(weight.imperial, ';')[safe_offset(0)], ':')[safe_offset(1)])
            else weight.imperial
        end as weight_male_lbs,
        case
            when weight.imperial like '%Female%'
            then trim(split(split(weight.imperial, ';')[safe_offset(1)], ':')[safe_offset(1)])
            else weight.imperial
        end as weight_female_lbs
    from source
)

select * from renamed