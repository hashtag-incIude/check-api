class UpdateDefaultValueForJsonbColumns < ActiveRecord::Migration[5.2]
  def change
    change_column_default :dynamic_annotation_annotation_types, :json_schema, from: '{}', to: {}
    execute "UPDATE dynamic_annotation_annotation_types SET json_schema = '{}'::jsonb WHERE json_schema = '\"{}\"'"
    change_column_default :dynamic_annotation_fields, :value_json, from: '{}', to: {}
    execute "UPDATE dynamic_annotation_fields SET value_json = '{}'::jsonb WHERE value_json = '\"{}\"'"
  end
end
