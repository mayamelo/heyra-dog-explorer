{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.schema in ('silver_dev', 'gold_dev') -%}
        {{ custom_schema_name }}_dev
    {%- else -%}
        {{ custom_schema_name }}
    {%- endif -%}
{%- endmacro %}