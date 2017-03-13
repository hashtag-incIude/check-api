module AnnotationBase
  extend ActiveSupport::Concern

  module Association
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def define_annotators_method
        define_method :annotators do
          query = self.annotation_query
          query[:annotator_type] = 'User'
          annotators = []
          Annotation.group(:annotator_id, :id).having(query).each do |result|
            annotators << User.find(result.annotator_id)
          end
          annotators.uniq
        end
      end

      def define_annotation_relation_method
        define_method :annotation_relation do |type=nil|
          query = self.annotation_query(type)
          klass = (type.blank? || type.is_a?(Array)) ? Annotation : type.camelize.constantize
          relation = klass.where(query)
          relation.order('id DESC')
        end
      end

      def has_annotations
        define_method :annotation_query do |type=nil|
          matches = { annotated_type: self.class_name, annotated_id: self.id }
          matches[:annotation_type] = [*type] unless type.nil?
          matches
        end

        define_annotation_relation_method

        define_method :annotations do |type=nil|
          self.annotation_relation(type).all
        end

        define_method :annotations_count do |type=nil|
          self.annotation_relation(type).count
        end

        define_method :add_annotation do |annotation|
          annotation.annotated = self
          annotation.save
        end

        define_annotators_method
      end
    end
  end

  included do
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include PaperTrail::Model
    include CheckPermissions
    include CheckNotifications::Slack
    include CheckNotifications::Pusher
    include CheckElasticSearch

    attr_accessor :disable_es_callbacks
    self.table_name = 'annotations'

    notifies_pusher on: :save,
                    if: proc { |a| a.annotated_type === 'ProjectMedia' },
                    event: 'media_updated',
                    targets: proc { |a| [a.annotated.project, a.annotated.media] },
                    data: proc { |a| a.to_json }

    before_validation :set_type_and_event, :set_annotator
    after_initialize :start_serialized_fields

    has_paper_trail on: [:create, :update], save_changes: true, ignore: [:updated_at, :created_at, :id, :entities], if: proc { |_x| User.current.present? }

    serialize :data, HashWithIndifferentAccess
    serialize :entities, Array

    def self.annotated_types
      ['ProjectSource', 'ProjectMedia', 'Source']
    end
    validates :annotated_type, included: { values: self.annotated_types }, allow_blank: true, :unless => Proc.new { |annotation| annotation.annotation_type == 'embed' }

    private

    def start_serialized_fields
      self.data ||= {}
      self.entities ||= []
    end
  end

  module ClassMethods
    def all_sorted(order = 'asc', field = 'created_at')
      type = self.name.parameterize
      query = type === 'annotation' ? {} : { annotation_type: type }
      Annotation.where(query).order(field => order.to_sym).all
    end

    def length
      type = self.name.parameterize
      Annotation.where(annotation_type: type).count
    end

    def field(name, _type = String, _options = {})
      define_method "#{name}=" do |value=nil|
        self.data ||= {}
        self.data[name.to_sym] = value
      end

      define_method name do
        self.data ||= {}
        self.data[name.to_sym]
      end
    end

    def annotation_notifies_slack(event)
      notifies_slack on: event,
                     if: proc { |a| a.should_notify? },
                     message: proc { |a| a.slack_message },
                     channel: proc { |a| a.annotated.project.setting(:slack_channel) || a.current_team.setting(:slack_channel) },
                     webhook: proc { |a| a.current_team.setting(:slack_webhook) }
    end
  end

  def versions(options = {})
    PaperTrail::Version.where(options).where(item_type: [self.class.to_s], item_id: self.id).order('id ASC')
  end

  def source
    self.annotated
  end

  def project_media
    self.annotated
  end

  def project
    self.annotated
  end

  def annotated
    self.load_polymorphic('annotated')
  end

  def annotated=(obj)
    self.set_polymorphic('annotated', obj) unless obj.nil?
  end

  def annotator
    self.load_polymorphic('annotator')
  end

  def annotator=(obj)
    self.set_polymorphic('annotator', obj) unless obj.nil?
  end

  # Overwrite in the annotation type and expose the specific fields of that type
  def content
    fields = self.get_fields
    fields.empty? ? self.data.merge(self.image_data).to_json : fields.to_json
  end

  def get_fields
    DynamicAnnotation::Field.where(annotation_id: self.id).to_a
  end

  def is_annotation?
    true
  end

  def ==(annotation)
    annotation.respond_to?(:id) ? (self.id == annotation.id) : super
  end

  def dbid
    self.id
  end

  def relay_id(type)
    str = "#{type.capitalize}/#{self.id}"
    str += "/#{self.version.id}" unless self.version.nil?
    Base64.encode64(str)
  end

  def get_team
    team = []
    obj = self.annotated.project if self.annotated.respond_to?(:project)
    if !obj.nil? and obj.respond_to?(:team)
      team = [obj.team.id] unless obj.team.nil?
    end
    team
  end

  def current_team
    self.annotated.project.team if self.annotated_type === 'ProjectMedia'
  end

  def should_notify?
    User.current.present? && self.current_team.present? && self.current_team.setting(:slack_notifications_enabled).to_i === 1 && self.annotated_type === 'ProjectMedia'
  end

  # Supports only media for the time being
  def entity_objects
    ProjectMedia.where(id: self.entities).to_a
  end

  def method_missing(method, *args, &block)
    (args.empty? && !block_given?) ? self.data[method] : super
  end

  def annotation_type_class
    klass = nil
    begin
      klass = self.annotation_type.camelize.constantize
    rescue NameError
      klass = Dynamic
    end
    klass
  end

  def annotated_client_url
    "#{CONFIG['checkdesk_client']}/#{self.annotated.project.team.slug}/project/#{self.annotated.project_id}/media/#{self.annotated_id}"
  end

  def image_data
    if self.file.nil?
      {}
    else
      obj = self.load
      { embed: obj.embed_path, thumbnail: obj.thumbnail_path, original: obj.image_path }
    end
  end

  def annotator_id_callback(value, _mapping_ids = nil)
    user_callback(value)
  end

  def annotated_id_callback(value, _mapping_ids = nil)
    ProjectMedia.first.id
    # mapping_ids[value]
  end

  protected

  def load_polymorphic(name)
    type, id = self.send("#{name}_type"), self.send("#{name}_id")
    return nil if type.blank? && id.blank?
    Rails.cache.fetch("find_#{type.parameterize}_#{id}", expires_in: 30.seconds, race_condition_ttl: 30.seconds) do
      type.constantize.find(id)
    end
  end

  def set_polymorphic(name, obj)
    self.send("#{name}_type=", obj.class_name)
    self.send("#{name}_id=", obj.id)
  end

  private

  def set_type_and_event
    self.annotation_type ||= self.class_name.parameterize
    self.paper_trail_event = 'create' if self.versions.count === 0
  end

  def set_annotator
    self.annotator = User.current if self.annotator.nil? && !User.current.nil?
  end
end
