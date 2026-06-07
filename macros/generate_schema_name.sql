{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name }}
    {%- else -%}
        {{ custom_schema_name }}_dev
    {%- endif -%}
{%- endmacro %}