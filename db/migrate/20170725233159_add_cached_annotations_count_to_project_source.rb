class AddCachedAnnotationsCountToProjectSource < ActiveRecord::Migration[4.2]
  def change
    add_column :project_sources, :cached_annotations_count, :integer, default: 0
  end
end
