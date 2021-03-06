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

  def random_valid_phone
    "00201".to_s + random_number(2).to_s +  8.times.map{rand(9)}.join
  end

  def random_machine_name
    name = random_string(5) + '_' + random_string(5) + '_' + random_string(5)
    name.downcase
  end

  def random_ip
    "%d.%d.%d.%d" % [rand(256), rand(256), rand(256), rand(256)]
  end

  def create_api_key(options = {})
    a = ApiKey.new
    options.each do |key, value|
      a.send("#{key}=", value) if a.respond_to?("#{key}=")
    end
    a.save!
    a.reload
  end

  def create_bot_user(options = {})
    u = BotUser.new
    u.name = options[:name] || random_string
    u.login = options.has_key?(:login) ? options[:login] : random_string
    u.email = options[:email] || "#{random_string}@#{random_string}.com"
    u.password = options[:password] || random_string
    u.password_confirmation = options[:password_confirmation] || u.password
    u.is_admin = options[:is_admin] if options.has_key?(:is_admin)
    u.api_key_id = options.has_key?(:api_key_id) ? options[:api_key_id] : create_api_key.id

    file = nil
    if options.has_key?(:image)
      file = options[:image]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        u.image = f
      end
    end

    u.save!
    u.source.set_avatar(options[:profile_image]) if options.has_key?(:profile_image) && u.source

    if options[:team]
      create_team_user team: options[:team], user: u
    end

    u.reload
  end

  def create_user(options = {})
    return create_omniauth_user(options) if options.has_key?(:provider) && !options[:provider].blank?
    u = User.new
    u.name = options.has_key?(:name) ? options[:name] : random_string
    u.login = options.has_key?(:login) ? options[:login] : random_string
    u.token = options.has_key?(:token) ? options[:token] : random_string(50)
    u.email = options[:email] || "#{random_string}@#{random_string}.com"
    u.password = options.has_key?(:password) ? options[:password] : random_string
    u.password_confirmation = options[:password_confirmation] || u.password
    u.current_team_id = options[:current_team_id] if options.has_key?(:current_team_id)
    u.is_admin = options[:is_admin] if options.has_key?(:is_admin)
    u.is_active = options[:is_active] if options.has_key?(:is_active)
    u.type = options[:type] if options.has_key?(:type)
    u.api_key_id = options[:api_key_id]

    file = nil
    if options.has_key?(:image)
      file = options[:image]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        u.image = f
      end
    end

    u.skip_confirmation! if options.has_key?(:skip_confirmation) && options[:skip_confirmation] == true

    u.save!
    u.source.set_avatar(options[:profile_image]) if options.has_key?(:profile_image) && u.source

    if options[:team]
      create_team_user team: options[:team], user: u
    end

    confirm = options.has_key?(:confirm) ? options[:confirm] : true
    if confirm
      u.skip_check_ability = true
      u.confirm
    end

    u.reload
  end

  def create_omniauth_user(options = {})
    u_current = User.current
    url = if options.has_key?(:url)
            options[:url]
    else
      pender_url = CONFIG['pender_url_private'] + '/api/medias'
      url = random_url
      options[:data] ||= {}
      data = { url: url, provider: 'twitter', author_picture: 'http://provider/picture.png', title: 'Foo Bar', description: 'Just a test', type: 'profile', author_name: 'Foo Bar' }.merge(options[:data])
      WebMock.stub_request(:get, pender_url).with({ query: { url: url } }).to_return(body: '{"type":"media","data":' + data.to_json + '}')
      url
    end
    options[:uid] = options[:uuid] if options.has_key?(:uuid)
    auth = {}
    provider = options.has_key?(:provider) ? options[:provider] : %w(twitter facebook).sample
    email = options.has_key?(:email) ? options[:email] : "#{random_string}@#{random_string}.com"
    auth[:uid] = options.has_key?(:uid) ? options[:uid] : random_string
    auth[:url] = url
    auth[:info] = options.has_key?(:info) ? options[:info] : {name: random_string, email: email}
    auth[:credentials] = options.has_key?(:credentials) ? options[:credentials] : {token: random_string, secret: random_string}
    auth[:extra] = options.has_key?(:extra) ? options[:extra] : {}
    current_user = options.has_key?(:current_user) ? options[:current_user] : nil
    omniauth = OmniAuth.config.add_mock(provider, auth)
    u = User.from_omniauth(omniauth, current_user)
    # reset User.current as `User.from_omniauth`  set User.current with recent created user
    User.current = u_current
    OmniAuth.config.mock_auth[provider] = nil

    if options.has_key?(:is_admin) && options[:is_admin]
      u.is_admin = options[:is_admin]
      u.skip_check_ability = true
      u.save!
    end
    if options.has_key?(:token)
      a = u.get_social_accounts_for_login({provider: provider, uid: auth[:uid]}).last
      a.update_columns(token: options[:token]) unless a.nil?
    end
    if options[:team]
      create_team_user team: options[:team], user: u
    end
    u.reload
  end

  def create_comment(options = {})
    user = options[:user] || create_user
    options = { text: random_string(50), annotator: user, disable_es_callbacks: true }.merge(options)
    unless options.has_key?(:annotated)
      t = options[:team] || create_team
      p = create_project team: t
      options[:annotated] = create_project_media project: p
    end
    c = Comment.new
    options.each do |key, value|
      c.send("#{key}=", value) if c.respond_to?("#{key}=")
    end

    file = nil
    if options.has_key?(:file)
      file = options[:file]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        c.file = f
      end
    end

    c.save!
    c
  end

  def create_tag(options = {})
    options = { tag: random_string(50), annotator: create_user, disable_es_callbacks: true }.merge(options)
    unless options.has_key?(:annotated)
      t = options[:team] || create_team
      p = create_project team: t
      options[:annotated] = create_project_media project: p
    end
    t = Tag.new
    options.each do |key, value|
      t.send("#{key}=", value) if t.respond_to?("#{key}=")
    end
    t.save!
    t
  end

  def create_verification_status_stuff(delete_existing = true)
    if delete_existing
      [DynamicAnnotation::FieldType, DynamicAnnotation::AnnotationType, DynamicAnnotation::FieldInstance].each { |klass| klass.delete_all }
      create_annotation_type_and_fields('Metadata', { 'Value' => ['JSON', false] })
    end
    ft1 = DynamicAnnotation::FieldType.where(field_type: 'text').last || create_field_type(field_type: 'text', label: 'Text')
    ft2 = DynamicAnnotation::FieldType.where(field_type: 'select').last || create_field_type(field_type: 'select', label: 'Select')
    at = create_annotation_type annotation_type: 'verification_status', label: 'Verification Status'
    create_field_instance annotation_type_object: at, name: 'verification_status_status', label: 'Verification Status', default_value: 'undetermined', field_type_object: ft2, optional: false
    create_field_instance annotation_type_object: at, name: 'title', label: 'Title', field_type_object: ft1, optional: true
    create_field_instance annotation_type_object: at, name: 'content', label: 'Content', field_type_object: ft1, optional: true
    create_field_instance annotation_type_object: at, name: 'published_article_url', label: 'Published Article URL', field_type_object: ft1, optional: true
    create_field_instance annotation_type_object: at, name: 'date_published', label: 'Date Published', field_type_object: ft1, optional: true
    create_field_instance annotation_type_object: at, name: 'raw', label: 'Raw', field_type_object: ft1, optional: true
    create_field_instance annotation_type_object: at, name: 'external_id', label: 'External ID', field_type_object: ft1, optional: true
  end

  def create_metadata_stuff
    at = DynamicAnnotation::AnnotationType.where(annotation_type: 'metadata').last || create_annotation_type(annotation_type: 'metadata', label: 'Metadata')
    ft = DynamicAnnotation::FieldType.where(field_type: 'json').last || create_field_type(field_type: 'json', label: 'JSON')
    DynamicAnnotation::FieldInstance.where(name: 'metadata_value').last || create_field_instance(annotation_type_object: at, name: 'metadata_value', label: 'Metadata Value', field_type_object: ft, optional: false, settings: {})
    create_verification_status_stuff(false) unless DynamicAnnotation::AnnotationType.where(annotation_type: 'verification_status').exists?
  end

  def create_task_status_stuff(delete_existing = true)
    if delete_existing
      [DynamicAnnotation::FieldType, DynamicAnnotation::AnnotationType, DynamicAnnotation::FieldInstance].each { |klass| klass.delete_all }
      create_annotation_type_and_fields('Metadata', { 'Value' => ['JSON', false] })
    end
    ft1 = DynamicAnnotation::FieldType.where(field_type: 'select').last || create_field_type(field_type: 'select', label: 'Select')
    at = create_annotation_type annotation_type: 'task_status', label: 'Task Status'
    create_field_instance annotation_type_object: at, name: 'task_status_status', label: 'Task Status', default_value: 'unresolved', field_type_object: ft1, optional: true
  end

  def create_task_stuff(delete_existing = true)
    if delete_existing
      [DynamicAnnotation::FieldType, DynamicAnnotation::AnnotationType, DynamicAnnotation::FieldInstance].each { |klass| klass.delete_all }
      create_annotation_type_and_fields('Metadata', { 'Value' => ['JSON', false] })
    end
    sel = create_field_type field_type: 'select', label: 'Select'
    text = create_field_type field_type: 'text', label: 'Text'
    at = create_annotation_type annotation_type: 'task_response_single_choice', label: 'Task Response Single Choice'
    create_field_instance annotation_type_object: at, name: 'response_single_choice', label: 'Response', field_type_object: sel, optional: false, settings: { multiple: false }
    at = create_annotation_type annotation_type: 'task_response_multiple_choice', label: 'Task Response Multiple Choice'
    create_field_instance annotation_type_object: at, name: 'response_multiple_choice', label: 'Response', field_type_object: sel, optional: false, settings: { multiple: true }
    at = create_annotation_type annotation_type: 'task_response_free_text', label: 'Task Response Free Text'
    create_field_instance annotation_type_object: at, name: 'response_free_text', label: 'Response', field_type_object: text, optional: false
  end

  # Verification status
  def create_status(options = {})
    create_verification_status_stuff if User.current.nil?
    options = { status: 'in_progress', annotator: create_user, disable_es_callbacks: true }.merge(options)
    unless options.has_key?(:annotated)
      t = options[:team] || create_team
      p = create_project team: t
      pm = create_project_media project: p
      remove_default_status(pm)
      options[:annotated] = pm
    end
    s = Dynamic.new
    s.annotation_type = 'verification_status'
    s.set_fields = { verification_status_status: options[:status] }.to_json
    options.except(:status).each do |key, value|
      s.send("#{key}=", value) if s.respond_to?("#{key}=")
    end
    s.annotated.reload if s.annotated
    s.save!
    s
  end

  def remove_default_status(obj)
    return unless obj.class.name == 'ProjectMedia'
    s = obj.last_status_obj
    s.destroy
  end

  def create_flag_annotation_type
    json_schema = {
      type: 'object',
      required: ['flags'],
      properties: {
        flags: {
          type: 'object',
          required: ['adult', 'spoof', 'medical', 'violence', 'racy', 'spam'],
          properties: {
            adult: { type: 'integer', minimum: 0, maximum: 5 },
            spoof: { type: 'integer', minimum: 0, maximum: 5 },
            medical: { type: 'integer', minimum: 0, maximum: 5 },
            violence: { type: 'integer', minimum: 0, maximum: 5 },
            racy: { type: 'integer', minimum: 0, maximum: 5 },
            spam: { type: 'integer', minimum: 0, maximum: 5 }
          }
        }
      }
    }
    create_annotation_type_and_fields('Flag', {}, json_schema)
  end

  def create_report_design_annotation_type
    json_schema = {
      type: 'object',
      properties: {
        state: { type: 'string', default: 'paused' },
        last_error: { type: 'string', default: '' },
        last_published: { type: 'string', default: '' },
        options: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              use_introduction: { type: 'boolean', default: false },
              introduction: { type: 'string', default: '' },
              use_visual_card: { type: 'boolean', default: false },
              visual_card_url: { type: 'string', default: '' },
              image: { type: 'string', default: '' },
              headline: { type: 'string', default: '' },
              description: { type: 'string', default: '' },
              status_label: { type: 'string', default: '' },
              previous_published_status_label: { type: 'string', default: '' },
              theme_color: { type: 'string', default: '' },
              url: { type: 'string', default: '' },
              use_text_message: { type: 'boolean', default: false },
              title: { type: 'string', default: '' },
              text: { type: 'string', default: '' },
              date: { type: 'string', default: '' },
              use_disclaimer: { type: 'boolean', default: false },
              disclaimer: { type: 'string', default: '' }
            }
          }
        }
      }
    }
    create_annotation_type_and_fields('Report Design', {}, json_schema)
  end

  def create_flag(options = {})
    create_flag_annotation_type if DynamicAnnotation::AnnotationType.where(annotation_type: 'flag').last.nil?
    flags = {
      'adult': 0,
      'spoof': 1,
      'medical': 2,
      'violence': 3,
      'racy': 4,
      'spam': 5
    }
    options = { set_fields: { flags: flags }.to_json, annotator: create_user }.merge(options)
    unless options.has_key?(:annotated)
      t = options[:team] || create_team
      p = create_project team: t
      options[:annotated] = create_project_media project: p
    end
    f = Dynamic.new
    f.annotation_type = 'flag'
    options.each do |key, value|
      f.send("#{key}=", value)
    end
    f.save!
    f
  end

  def create_metadata(options = {})
    annotator = options[:annotator] || create_user
    options = { annotator: annotator, disable_es_callbacks: true }.merge(options)
    options[:annotated] = create_media unless options.has_key?(:annotated)
    m = Dynamic.new
    m.annotation_type = 'metadata'
    data = {}
    options.each do |key, value|
      if m.respond_to?("#{key}=")
        m.send("#{key}=", value)
      else
        data[key] = value
      end
    end
    m.set_fields = { metadata_value: data.to_json }.to_json
    m.save!
    m
  end

  def create_annotation(options = {})
    if options.has_key?(:annotation_type) && options[:annotation_type].blank?
      Annotation.create!(options)
    else
      create_comment(options)
    end
  end

  def create_account(options = {})
    options = { disable_es_callbacks: true }.merge(options)
    return create_valid_account(options) unless options.has_key?(:url)
    account = Account.new
    account.url = options[:url]
    if options.has_key?(:user_id)
      account.user_id = options[:user_id]
    else
      account.user = options[:user] || create_user
    end
    if options.has_key?(:team_id)
      account.team_id = options[:team_id]
    elsif options.has_key?(:team)
      account.team = options[:team]
    end
    account.disable_es_callbacks = options[:disable_es_callbacks]
    account.skip_pender = options[:skip_pender] if options.has_key?(:skip_pender)
    account.source = options.has_key?(:source) ? options[:source] : create_source(team: options[:team])
    account.provider = options[:provider]
    account.uid = options[:uid]
    account.email = options[:email]
    account.omniauth_info = options[:omniauth_info]
    account.save!
    account.reload
  end

  def create_project(options = {})
    project = Project.new
    project.title = options[:title] || random_string
    project.description = options[:description] || random_string(40)
    project.user = options.has_key?(:user) ? options[:user] : create_user
    file = 'rails.png'
    if options.has_key?(:lead_image)
      file = options[:lead_image]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        project.lead_image = f
      end
    end
    project.archived = options[:archived] || false
    team = options[:team] || create_team
    project.team_id = options[:team_id] || team.id
    project.save!
    project.reload
  end

  def create_recent_project(options = {})
    create_project(options)
  end

  def create_team(options = {})
    team = Team.new
    team.name = options[:name] || random_string
    team.slug = options[:slug] || Team.slug_from_name(team.name)
    file = 'rails.png'
    if options.has_key?(:logo)
      file = options[:logo]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        team.logo = f
      end
    end
    team.archived = options[:archived] || false
    team.private = options.has_key?(:private) ? options[:private] : false
    team.description = options[:description] || random_string
    team.save!
    team.disable_es_callbacks = options.has_key?(:disable_es_callbacks) ? options[:disable_es_callbacks] : true
    team.reload
  end

  def create_media(options = {})
    return create_valid_media(options) if options[:url].blank?
    account = options.has_key?(:account) ? options[:account] : create_account
    user = options.has_key?(:user) ? options[:user] : create_user
    type = options.has_key?(:type) ? options[:type] : :link
    m = type.to_s.camelize.constantize.new
    m.url = options[:url]
    m.quote = options[:quote] if options.has_key?(:quote)
    m.account_id = options.has_key?(:account_id) ? options[:account_id] : account.id
    m.user_id = options.has_key?(:user_id) ? options[:user_id] : user.id
    m.disable_es_callbacks = options.has_key?(:disable_es_callbacks) ? options[:disable_es_callbacks] : true

    file = nil
    if options.has_key?(:file)
      file = options[:file]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        m.file = f
      end
    end

    m.save!
    unless options[:project_id].blank?
      p = Project.where(id: options[:project_id]).last
      create_project_media media: m, project: p unless p.nil?
    end
    m.reload
  end

  def create_link(options = {})
    create_media(options.merge({ type: 'link' }))
  end

  def create_uploaded_image(options = { file: 'rails.png' })
    create_media(options.merge({ type: 'UploadedImage' }))
  end

  def create_uploaded_file(options = { file: 'test.txt' })
    create_media(options.merge({ type: 'UploadedFile' }))
  end

  def create_claim_media(options = {})
    options = { quote: random_string }.merge(options)
    c = Claim.new
    options.each do |key, value|
      c.send("#{key}=", value) if c.respond_to?("#{key}=")
    end
    c.save!
    c.reload
  end

  def create_uploaded_video(options = { file: 'rails.mp4' })
    create_media(options.merge({ type: 'UploadedVideo' }))
  end

  def create_uploaded_audio(options = { file: 'rails.mp3' })
    create_media(options.merge({ type: 'UploadedAudio' }))
  end

  def create_source(options = {})
    source = Source.new
    source.name = options[:name] || random_string
    source.slogan = options[:slogan] || random_string(20)
    source.user = options[:user]
    source.avatar = options[:avatar]
    source.team = options[:team] if options.has_key?(:team)
    source.disable_es_callbacks = options.has_key?(:disable_es_callbacks) ? options[:disable_es_callbacks] : true
    file = nil
    if options.has_key?(:file)
      file = options[:file]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        source.file = f
      end
    end
    source.save!
    source.reload
  end

  def create_account_source(options = {})
    as = AccountSource.new
    options[:source_id] = create_source.id if !options.has_key?(:source_id) && !options.has_key?(:source)
    options[:account_id] = create_valid_account.id if !options.has_key?(:account_id) && !options.has_key?(:account) && !options.has_key?(:url)
    options.each do |key, value|
      as.send("#{key}=", value) if as.respond_to?("#{key}=")
    end
    as.save!
    as.reload
  end

  def create_project_media(options = {})
    u = options[:user] || create_user
    options = { disable_es_callbacks: true, user: u }.merge(options)
    options[:media_type] = 'Link' unless options[:url].blank?
    options[:media_type] = 'Claim' unless options[:quote].blank?
    pm = ProjectMedia.new
    if options.has_key?(:project) && !options[:project].nil?
      options[:team] = options[:project].team
      options[:add_to_project_id] = options[:project].id unless options.has_key?(:add_to_project_id)
    end
    options[:team] = create_team unless options.has_key?(:team)
    options[:media] = create_valid_media unless options.has_key?(:media)
    options.each do |key, value|
      pm.send("#{key}=", value) if pm.respond_to?("#{key}=")
    end
    pm.save!
    pm.reload
  end

  def create_version(options = {})
    User.current = options[:user] || create_user
    t = create_team
    v = t.versions.from_partition(t.id).last
    User.current = nil
    v
  end

  def create_team_user(options = {})
    tu = TeamUser.new
    team = options[:team] || create_team
    user = options[:user] || create_user
    tu.team = Team.find_by_id(options[:team_id]) || team
    tu.user = User.find_by_id(options[:user_id]) || user
    tu.role = options[:role]
    tu.status = options[:status] || 'member'
    tu.save!
    tu.reload
  end

  def create_valid_media(options = {})
    pender_url = CONFIG['pender_url_private'] + '/api/medias'
    url = random_url
    params = { url: url }
    params[:archivers] = Team.current.enabled_archivers if !Team.current&.enabled_archivers.blank?
    WebMock.stub_request(:get, pender_url).with({ query: params }).to_return(body: '{"type":"media","data":{"url":"' + url + '","type":"item","archives":{}}}')
    create_media({ account: create_valid_account }.merge(options).merge({ url: url }))
  end

  def create_valid_account(options = {})
    pender_url = CONFIG['pender_url_private'] + '/api/medias'
    url = random_url
    options[:data] ||= {}
    data = { url: url, provider: 'twitter', author_picture: 'http://provider/picture.png', title: 'Foo Bar', description: 'Just a test', type: 'profile', author_name: 'Foo Bar' }.merge(options[:data])
    params = { url: CGI.escape(url) }
    params[:archivers] = Team.current.enabled_archivers if !Team.current&.enabled_archivers.blank?
    WebMock.stub_request(:get, pender_url).with({ query: params }).to_return(body: '{"type":"media","data":' + data.to_json + '}')
    options.merge!({ url: CGI.escape(url) })
    create_account(options)
  end

  def create_contact(options = {})
    contact = Contact.new
    contact.location = options[:location] || random_string
    contact.phone = options[:phone] || random_valid_phone
    contact.web = options[:web] || random_url
    if options.has_key?(:team_id)
      contact.team_id = options[:team_id]
    else
      contact.team = options[:team] || create_team
    end
    contact.save!
    contact.reload
  end

  def create_bot(options = {})
    bot = BotUser.new
    bot.name = options[:name] || random_string
    file = 'rails.png'
    if options.has_key?(:avatar)
      file = options[:avatar]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        bot.image = f
      end
    end
    bot.save!
    bot.reload
  end

  def create_alegre_bot(_options = {})
    Bot::Alegre.new
  end

  def create_slack_bot(_options = {})
    b = create_team_bot(type: 'Bot::Slack')
    Bot::Slack.find(b.id)
  end

  def create_bounce(options = {})
    b = Bounce.new
    b.email = options.has_key?(:email) ? options[:email] : random_email
    b.save!
    b.reload
  end

  def get_es_id(obj)
    Base64.encode64("#{obj.class.name}/#{obj.id}")
  end

  def create_media_search(options = {})
    ms = ElasticItem.new
    pm = options[:project_media] || create_project_media
    options[:id] = get_es_id(pm)
    options[:annotated_id] = pm.id
    options[:annotated_type] = pm.class.name
    options.each do |key, value|
      ms.attributes[key] = value
    end
    $repository.save(ms)
    sleep 1
    $repository.find(options[:id])
  end

  def create_annotation_type(options = {})
    at = DynamicAnnotation::AnnotationType.new
    at.annotation_type = options.has_key?(:annotation_type) ? options[:annotation_type] : random_machine_name
    at.label = options.has_key?(:label) ? options[:label] : random_string(10)
    at.description = options.has_key?(:description) ? options[:description] : ''
    at.singleton = options[:singleton] if options.has_key?(:singleton)
    at.json_schema = options[:json_schema] if at.respond_to?('json_schema=') && options.has_key?(:json_schema)
    at.skip_check_ability = true
    at.save!
    at
  end

  def create_field_type(options = {})
    ft = DynamicAnnotation::FieldType.new
    ft.field_type = options.has_key?(:field_type) ? options[:field_type] : random_machine_name
    ft.label = options.has_key?(:label) ? options[:label] : random_string(10)
    ft.description = options.has_key?(:description) ? options[:description] : ''
    ft.save!
    ft
  end

  def create_field_instance(options = {})
    fi = DynamicAnnotation::FieldInstance.new
    fi.name = options.has_key?(:name) ? options[:name] : random_machine_name
    fi.field_type_object = options.has_key?(:field_type_object) ? options[:field_type_object] : create_field_type
    fi.annotation_type_object = options.has_key?(:annotation_type_object) ? options[:annotation_type_object] : create_annotation_type
    fi.label = options.has_key?(:label) ? options[:label] : random_string
    fi.description = options[:description]
    fi.optional = options[:optional] if options.has_key?(:optional)
    fi.settings = options[:settings] if options.has_key?(:settings)
    fi.default_value = options[:default_value] || ''
    fi.save!
    fi
  end

  def create_field(options = {})
    f = DynamicAnnotation::Field.new
    f.annotation_id = options.has_key?(:annotation_id) ? options[:annotation_id] : create_dynamic_annotation.id
    f.annotation_type = options[:annotation_type] if options.has_key?(:annotation_type)
    f.field_type = options[:field_type] if options.has_key?(:field_type)
    f.field_name = options.has_key?(:field_name) ? options[:field_name] : create_field_instance.name
    f.value = options.has_key?(:value) ? options[:value] : random_string
    if options[:skip_validation]
      f.save(validate: false)
    else
      f.save!
    end
    f.reload
  end

  def create_dynamic_annotation(options = {})
    t = options[:annotation_type]
    create_annotation_type(annotation_type: t) if !options[:skip_create_annotation_type] && !t.blank? && !DynamicAnnotation::AnnotationType.where(annotation_type: t).exists?
    a = Dynamic.new
    a.annotation_type = t
    a.annotator = options.has_key?(:annotator) ? options[:annotator] : create_user
    if options[:annotated_id] && options[:annotated_type]
      a.annotated_id = options[:annotated_id]
      a.annotated_type = options[:annotated_type]
    else
      a.annotated = options[:annotated] || create_project_media
    end
    a.set_fields = options[:set_fields]
    a.disable_es_callbacks = options.has_key?(:disable_es_callbacks) ? options[:disable_es_callbacks] : true
    file = nil
    if options.has_key?(:file)
      file = options[:file]
    end
    unless file.nil?
      File.open(File.join(Rails.root, 'test', 'data', file)) do |f|
        a.file = [f]
      end
    end
    a.action = options[:action]
    a.save!
    a
  end

  def create_task(options = {})
    options = {
      label: '5 + 5 = ?',
      type: 'single_choice',
      description: 'Please solve this math puzzle',
      options: ['10', '20', '30'],
      status: 'unresolved',
      annotator: options[:user] || create_user,
      fieldset: 'tasks',
      disable_es_callbacks: true,
    }.merge(options)
    unless options.has_key?(:annotated)
      t = options[:team] || create_team
      p = create_project team: t
      options[:annotated] = create_project_media project: p
    end
    t = Task.new
    options.each do |key, value|
      t.send("#{key}=", value) if t.respond_to?("#{key}=")
    end
    t.save!
    t
  end

  def create_annotation_type_and_fields(annotation_type_label, fields, json_schema = nil)
    # annotation_type_label = 'Annotation Type'
    # fields = {
    #   Name => [Type Label, optional = true, settings (optional)],
    #   ...
    # }
    annotation_type_name = annotation_type_label.parameterize.tr('-', '_')
    if Bot::Keep.archiver_annotation_types.include?(annotation_type_name)
      field_name_prefix = annotation_type_name
      annotation_type_name = 'archiver'
      annotation_type_label = 'Archiver'
    end
    at = DynamicAnnotation::AnnotationType.where(annotation_type: annotation_type_name).last || create_annotation_type(annotation_type: annotation_type_name, label: annotation_type_label, json_schema: json_schema)
    if json_schema.nil?
      fts = fields.values.collect{ |v| v.first }
      fts.each do |label|
        type = label.parameterize.tr('-', '_')
        DynamicAnnotation::FieldType.where(field_type: type).last || create_field_type(field_type: type, label: label)
      end
      fields.each do |label, type|
        field_label = annotation_type_label + ' ' + label
        field_name = (field_name_prefix || annotation_type_name) + '_' + label.parameterize.tr('-', '_')
        optional = type[1].nil? ? true : type[1]
        settings = type[2] || {}
        field_type = type[0].parameterize.tr('-', '_')
        type_object = DynamicAnnotation::FieldType.where(field_type: field_type).last
        DynamicAnnotation::FieldInstance.where(name: field_name).last || create_field_instance(annotation_type_object: at, name: field_name, label: field_label, field_type_object: type_object, optional: optional, settings: settings)
      end
    end
  end

  def create_relationship(options = {})
    t = create_team
    source_id = options[:source_id] || create_project_media(team: t).id
    target_id = options[:target_id] || create_project_media(team: t).id
    options = {
      source_id: source_id,
      target_id: target_id,
      relationship_type: { source: 'parent', target: 'child' }
    }.merge(options)
    r = Relationship.new
    options.each do |key, value|
      r.send("#{key}=", value) if r.respond_to?("#{key}=")
    end
    r.save!
    r
  end

  def create_team_bot(options = {})
    options = {
      name: random_string,
      set_description: random_string,
      set_request_url: random_url,
      team_author_id: create_team.id,
      set_events: [{ event: 'create_project_media', graphql: nil }]
    }.merge(options)

    tb = BotUser.new
    options.each do |key, value|
      if key.to_s =~ /^set_/
        tb.send(key, value)
      elsif tb.respond_to?("#{key}=")
        tb.send("#{key}=", value)
      end
    end

    File.open(File.join(Rails.root, 'test', 'data', 'rails.png')) do |f|
      tb.image = f
    end

    tb.save!
    tb
  end

  def create_team_bot_installation(options = {})
    options[:team_id] = create_team.id unless options.has_key?(:team_id)
    options[:user_id] = create_team_bot(set_approved: true).id unless options.has_key?(:user_id)
    tbi = TeamBotInstallation.new
    options.each do |key, value|
      tbi.send("#{key}=", value) if tbi.respond_to?("#{key}=")
    end
    tbi.save!
    tbi.reload
  end

  def create_tag_text(options = {})
    tt = TagText.new
    options = { text: random_string, team_id: create_team.id }.merge(options)
    options.each do |key, value|
      tt.send("#{key}=", value) if tt.respond_to?("#{key}=")
    end
    tt.save!
    tt
  end

  def create_team_task(options = {})
    tt = TeamTask.new
    options = { label: random_string, team_id: create_team.id, task_type: 'free_text', fieldset: 'tasks' }.merge(options)
    options.each do |key, value|
      tt.send("#{key}=", value) if tt.respond_to?("#{key}=")
    end
    tt.save!
    tt
  end

  def create_login_activity(options = {})
    la = LoginActivity.new
    la.user = options.has_key?(:user) ? options[:user] : create_user
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36"
    options = { identity: random_email, context: "api/v1/sessions#create", ip: random_ip, user_agent: user_agent }.merge(options)
    options.each do |key, value|
      la.send("#{key}=", value) if la.respond_to?("#{key}=")
    end
    la.save!
    la.reload
  end

  def create_project_media_project(options = {})
    pmp = ProjectMediaProject.new
    pmp.disable_es_callbacks = true
    options.each do |key, value|
      pmp.send("#{key}=", value) if pmp.respond_to?("#{key}=")
    end
    pmp.project_media = create_project_media unless options.has_key?(:project_media)
    pmp.project = create_project unless options.has_key?(:project)
    pmp.save!
    pmp.reload
  end

  def create_blank_media
    Blank.create!
  end
end
