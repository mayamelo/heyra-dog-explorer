with source as (
    select *
    from {{ ref('stg_dog_api_breeds') }}
),
final as (
    select
    *
from source
)
select * from final