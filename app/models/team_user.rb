class TeamUser < ActiveRecord::Base
  attr_accessible

  belongs_to :team
  belongs_to :user

  def user_id_callback(value, _mapping_ids = nil)
    user = User.where(name: value).last
    user.nil? ? nil : user.id
  end

  def team_id_callback(value, _mapping_ids = nil)
    team_id = _mapping_ids[value]
  end

end
