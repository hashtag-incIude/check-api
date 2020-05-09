class UpdateProjectForProjectSource < ActiveRecord::Migration[4.2]
  def change
    ProjectSource.find_each do |ps|
      pm =  ps.source.medias.first
      if !pm.nil? && ps.project_id != pm.project_id
        ps.project_id = pm.project_id
        ps.save
      end
    end
  end
end
