class RemoveMemebusterData < ActiveRecord::Migration
  def change
    Rails.cache.write('check:migrate:remove_memebuster_data:last_id', Dynamic.last&.id || 0)
  end
end
