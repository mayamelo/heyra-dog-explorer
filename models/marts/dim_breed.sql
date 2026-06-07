with source as (
    select *
    from {{ ref('stg_dog_api_breeds') }}
),
final as (
    select
    breed_id,
    breed_name,
    breed_group,
    origin,
    country_code,
    temperament,
    description,
    history,
    height_male_cm,
    height_female_cm,
    height_male_in,
    height_female_in,
    weight_male_kg,
    weight_female_kg,
    weight_male_lbs,
    weight_female_lbs
from source
)

select * from final