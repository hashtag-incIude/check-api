PaperTrail.config.track_associations = false
PaperTrail.serializer = PaperTrail::Serializers::JSON

module PaperTrail
  module AttributeSerializers
    class CastAttributeSerializer
      def initialize(klass)
        @klass = klass
      end
    end
  end

  module CheckdeskExtensions
    def self.included(base)
      base.class_eval do
        before_create :set_object_after, :set_user, :set_event_type
      end
    end

    def item_class
      self.item_type.constantize
    end

    def item
      self.item_class.where(id: self.item_id).last
    end

    def project_media
      self.item.project_media if self.item.respond_to?(:project_media)
    end

    def source
      self.item.source if self.item.respond_to?(:source)
    end

    def dbid
      self.id
    end

    def annotation
      Annotation.find(self.item_id) if self.item_class.new.is_annotation?
    end

    def user
      self.whodunnit.nil? ? nil : User.where(id: self.whodunnit.to_i).last
    end

    def get_object
      self.object.nil? ? {} : JSON.parse(self.object)
    end

    def apply_changes
      object = self.get_object
      changes = JSON.parse(self.object_changes)

      { 'is_annotation?' => 'data', Team => 'settings', DynamicAnnotation::Field => 'value' }.each do |condition, key|
        obj = self.item_class.new
        matches = condition.is_a?(String) ? obj.send(condition) : obj.is_a?(condition)
        if matches
          object[key] = self.deserialize_change(object[key]) if object[key]
          changes[key].collect!{ |change| self.deserialize_change(change) unless change.nil? } if changes[key]
        end
      end
      
      changes.each do |key, pair|
        object[key] = pair[1]
      end
      object.to_json
    end

    def set_object_after
      self.object_after = self.apply_changes
    end

    def set_user
      self.whodunnit = User.current.id.to_s if self.whodunnit.nil? && User.current.present?
    end

    def projects
      ret = []
      if self.item_type == 'ProjectMedia' && self.event == 'update'
        changes = JSON.parse(self.object_changes)
        if changes['project_id']
          ret = changes['project_id'].collect{ |pid| Project.where(id: pid).last }
          ret = [] if ret.include?(nil)
        end
      end
      ret
    end

    def task
      task = nil
      if self.item_type == 'DynamicAnnotation::Field'
        annotation = self.item.annotation
        if annotation.annotation_type =~ /^task_response_/
          annotation.get_fields.each do |field|
            task = Task.where(id: field.value.to_i).last if field.field_type == 'task_reference'
          end
        end
      end
      task
    end

    def deserialize_change(d)
      ret = d
      unless d.nil?
        ret = YAML.load(d)
      end
      ret
    end

    def object_changes_json
      changes = JSON.parse(self.object_changes)
      if changes['data'] && changes['data'].is_a?(Array)
        changes['data'].collect!{ |d| self.deserialize_change(d) }
      end
      changes.to_json
    end

    def set_event_type
      self.event_type = self.event + '_' + self.item_type.downcase.gsub(/[^a-z]/, '')
    end
  end
end

PaperTrail::Version.send(:include, PaperTrail::CheckdeskExtensions)
ActiveRecord::Base.send :include, AnnotationBase::Association
