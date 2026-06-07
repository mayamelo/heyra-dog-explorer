with source as (
    select *
    from {{ ref('stg_dog_api_breeds') }}
),
temperaments as (
    select
        breed_id,
        breed_name,
        breed_group,
        trim(temperament_trait) as temperament_trait
    from source,
    unnest(split(temperament, ',')) as temperament_trait
),
final as (
    select
        breed_id,
        breed_name,
        breed_group,
        lower(temperament_trait) as temperament_trait
    from temperaments
    where temperament_trait is not null
      and trim(temperament_trait) != ''
)
select * from final