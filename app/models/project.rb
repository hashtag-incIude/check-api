class Project < ActiveRecord::Base
  attr_accessible
  has_paper_trail on: [:update]
  belongs_to :user
  has_many :media
  has_many :project_sources
  has_many :sources , :through => :project_sources
  mount_uploader :lead_image, ImageUploader
  validates_presence_of :title

private
  def user_id_callback(value)
    user = User.find_by name: value
    ret_value =  user.id
  end

end
