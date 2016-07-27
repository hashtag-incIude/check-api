module SampleData

  # Methods to generate random data

  def random_string(length = 10)
    (0...length).map{ (65 + rand(26)).chr }.join
  end

  def random_url
    'http://' + random_string + '.com'
  end

  def random_number(max = 50)
    rand(max) + 1
  end

  def random_email
    random_string + '@' + random_string + '.com'
  end

  def create_api_key(options = {})
    a = ApiKey.new
    options.each do |key, value|
      a.send("#{key}=", value)
    end
    a.save!
    a.reload
  end

  def create_user(options = {})
    u = User.new
    u.name = options[:name] || random_string
    u.login = options.has_key?(:login) ? options[:login] : random_string
    u.profile_image = options[:profile_image] || random_url
    u.uuid = options.has_key?(:uuid) ? options[:uuid] : random_string
    u.provider = options.has_key?(:provider) ? options[:provider] : %w(twitter facebook).sample
    u.token = options.has_key?(:token) ? options[:token] : random_string(50)
    u.email = options[:email] || "#{random_string}@#{random_string}.com"
    u.password = options[:password] || random_string
    u.password_confirmation = options[:password_confirmation] || u.password
    u.url = options[:url] if options.has_key?(:url)
    u.save!
    u.reload
  end

  def create_comment(options = {})
    c = Comment.create({ text: random_string(50), annotator: create_user }.merge(options))
    sleep 1 if Rails.env.test?
    c.reload
  end

  def create_tag(options = {})
    t = Tag.create({ tag: random_string(50), annotator: create_user }.merge(options))
    sleep 1 if Rails.env.test?
    t.reload
  end

  def create_status(options = {})
    st = Status.create({ status: 'In Progress', annotator: create_user }.merge(options))
    sleep 1 if Rails.env.test?
    st.reload
  end

  def create_flag(options = {})
    f = Flag.create({ flag: 'spam', annotator: create_user }.merge(options))
    sleep 1 if Rails.env.test?
    f.reload
  end

  def create_annotation(options = {})
    Annotation.create(options)
  end

  def create_account(options = {})
    return create_valid_account(options) unless options.has_key?(:url)
    account = Account.new
    account.url = options[:url]
    account.data = options[:data] || {}
    if options.has_key?(:user_id)
      account.user_id = options[:user_id]
    else
      account.user = options[:user] || create_user
    end
    account.source = options[:source] || create_source
    account.save!
    account.reload
  end

  def create_project(options = {})
    project = Project.new
    project.title = options[:title] || random_string
    project.description = options[:description] || random_string(40)
    project.user = options[:user] || create_user
    project.lead_image = options[:lead_image]
    project.archived = options[:archived] || false
    project.save!
    project.reload
  end

  def create_team(options = {})
    team = Team.new
    team.name = options[:name] || random_string
    if options.has_key?(:logo)
      team.logo = options[:logo]
    else
      File.open(File.join(Rails.root, 'test', 'data', 'rails.png')) do |f|
        team.logo = f
      end
    end
    team.archived = options[:archived] || false
    team.description = options[:description] || random_string
    team.save!
    team.reload
  end

  def create_media(options = {})
    return create_valid_media(options) if options[:url].blank?
    account = options[:account] || create_account
    user = options[:user] || create_user
    m = Media.new
    m.url = options[:url]
    m.account_id = options[:account_id] || account.id
    m.user_id = options[:user_id] || user.id
    m.save!
    m.reload
  end

  def create_source(options = {})
    source = Source.new
    source.name = options[:name] || random_string
    source.slogan = options[:slogan] || random_string(20)
    source.user = options[:user]
    source.avatar = options[:avatar]
    source.save!
    source.reload
  end

  def create_project_source(options = {})
    ps = ProjectSource.new
    project = options[:project] || create_project
    source = options[:source] || create_source
    ps.project_id = options[:project_id] || project.id
    ps.source_id = options[:source_id] || source.id
    ps.save!
    ps.reload
  end

  def create_project_media(options = {})
    pm = ProjectMedia.new
    project = options[:project] || create_project
    media = options[:source] || create_valid_media
    pm.project_id = options[:project_id] || project.id
    pm.media_id = options[:media_id] || media.id
    pm.save!
    pm.reload
  end

  def create_team_user(options = {})
    tu = TeamUser.new
    team = options[:team] || create_team
    user = options[:user] || create_user
    tu.team_id = options[:team_id] || team.id
    tu.user_id = options[:user_id] || user.id
    tu.save!
    tu.reload
  end

  def create_valid_media(options = {})
    pender_url = CONFIG['pender_host'] + '/api/medias'
    url = random_url
    WebMock.stub_request(:get, pender_url).with({ query: { url: url } }).to_return(body: '{"type":"media","data":{"url":"' + url + '"}}')
    create_media({ account: create_valid_account }.merge(options).merge({ url: url }))
  end

  def create_valid_account(options = {})
    pender_url = CONFIG['pender_host'] + '/api/medias'
    url = random_url
    WebMock.stub_request(:get, pender_url).with({ query: { url: url } }).to_return(body: '{"type":"media","data":{"url":"' + url + '"}}')
    options.merge!({ url: url })
    create_account(options)
  end
end
