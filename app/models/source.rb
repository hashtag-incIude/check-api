class Source < ActiveRecord::Base
  include HasImage

  has_paper_trail on: [:create, :update], if: proc { |_x| User.current.present? }
  has_many :project_sources
  has_many :account_sources
  has_many :projects, through: :project_sources
  has_many :accounts, through: :account_sources
  belongs_to :user
  belongs_to :team

  has_annotations

  before_validation :set_user, :set_team, on: :create

  validates_presence_of :name

  def user_id_callback(value, _mapping_ids = nil)
    user_callback(value)
  end

  def avatar_callback(value, _mapping_ids = nil)
    image_callback(value)
  end

  def medias
    #TODO: fix me - list valid project media ids
    m_ids = Media.where(account_id: self.account_ids).map(&:id)
    conditions = { media_id: m_ids }
    conditions['projects.team_id'] = Team.current.id unless Team.current.nil?
    ProjectMedia.joins(:project).where(conditions)
  end

  def get_team
    teams = []
    projects = self.projects.map(&:id)
    teams = Project.where(:id => projects).map(&:team_id).uniq unless projects.empty?
    return teams
  end

  def image
    self.avatar || (self.accounts.empty? ? '' : self.accounts.first.data['picture'].to_s)
  end

  def description
    return self.slogan if self.slogan != self.name && !self.slogan.nil?
    self.accounts.empty? ? '' : self.accounts.first.data['description'].to_s
  end

  def collaborators
    self.annotators
  end

  def tags
    self.annotations('tag')
  end

  def comments
    self.annotations('comment')
  end

  def file_mandatory?
    false
  end

  private

  def set_user
    self.user = User.current unless User.current.nil?
  end

  def set_team
    self.team = Team.current unless Team.current.nil?
  end
end
