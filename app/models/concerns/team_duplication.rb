require 'active_support/concern'

module TeamDuplication
  extend ActiveSupport::Concern
  include ErrorNotification

  included do
    attr_accessor :mapping, :original_team, :copy_team

    def self.duplicate(t, user = nil)
      @mapping = {}
      @original_team = t
      @cloned_versions = []
      begin
        ActiveRecord::Base.transaction do
          Version.skip_callback(:create, :after, :increment_project_association_annotations_count)
          team = t.deep_clone include: [
            :sources,
            { projects: [:project_media_projects] },
            { project_medias: [versions: { if: lambda{|v| v.associated_id.blank? }}]},
            :team_users,
            :contacts,
            :team_tasks
          ] do |original, copy|
            @cloned_versions << copy if original.is_a?(Version)
            self.set_mapping(original, copy) unless original.is_a?(Version)
            self.copy_image(original, copy)
            self.versions_log_mapping(original, copy)
            self.flag_project_medias(original, copy)
          end
          team.slug = team.generate_copy_slug
          team.is_being_copied = true
          team.save(validate: false)
          @copy_team = team
          self.copy_annotations
          self.update_project_medias
          self.update_project_media_projects
          self.copy_relationships(@mapping[:"ProjectMedia"])
          self.copy_versions(@mapping[:"Version"])
          self.update_cloned_versions(@cloned_versions)
          self.create_copy_version(@mapping[:ProjectMedia], user)
          Version.set_callback(:create, :after, :increment_project_association_annotations_count)
          team
        end
      rescue StandardError => e
        self.log_error(e, t)
        nil
      end
    end

    def self.log_error(e, t)
      self.notify_error(e, { team_id: t.id }, RequestStore[:request])
      Rails.logger.error "[Team Duplication] Could not duplicate team #{t.slug}: #{e.message} #{e.backtrace.join("\n")}"
    end

    def self.flag_project_medias(original, copy)
      original.team.is_being_copied = true if original.is_a?(ProjectMedia)
      copy.team.is_being_copied = true if copy.is_a?(ProjectMedia)
    end

    def self.set_mapping(object, copy)
      key = object.class_name.to_sym
      @mapping[key] ||= {}
      @mapping[key][object.id] = copy
    end

    def self.copy_image(original, copy)
      [:logo, :lead_image, :file].each do |image|
        next unless original.respond_to?(image) && original.respond_to?("#{image}=") && original.send(image)
        [original.send(image)].flatten.each do |img|
          copy.send("#{image}=", open(img.url)) if img.url =~ /^#{CONFIG['storage']['endpoint']}/
        end
      end
    end

    def self.versions_log_mapping(original, copy)
      if original.respond_to?(:get_versions_log)
        original.get_versions_log.find_each do |log|
          self.set_mapping(log, copy)
        end
      end
    end

    def self.copy_annotations
      [:ProjectMedia, :Source, :Task].each do |type|
        next if @mapping[type].blank?
        @mapping[type].each_pair do |original, copy|
          type.to_s.constantize.find(original).annotations.find_each do |a|
            a = a.load
            annotation = a.dup
            annotation.annotated = copy
            annotation.is_being_copied = true
            annotation.skip_notifications = true
            Team.copy_image(a, annotation)
            annotation.save(validate: false)
            self.set_mapping(a, annotation)
            self.copy_annotation_fields(a, annotation)
          end
        end
      end
    end

    def self.copy_annotation_fields(original, copy)
      original.get_fields.each do |f|
        next unless f.is_a?(DynamicAnnotation::Field)
        field = f.dup
        field.annotation_id = copy.id
        field.save(validate: false)
        self.set_mapping(f, field)
      end
    end

    def self.copy_relationships(pm_mapping)
      return if pm_mapping.blank?
      Relationship.where(source_id: pm_mapping.keys).find_each do |r|
        copy_r = r.dup
        self.set_mapping(r, copy_r);
        copy_r.is_being_copied = true
        self.update_relationships(copy_r)
        copy_r.save(validate: false)
      end
    end

    def self.update_relationships(copy_r)
      [:source_id, :target_id].each do |r|
        pm_mapping = @mapping.dig(:ProjectMedia, copy_r.send(r))
        copy_r.send("#{r}=", pm_mapping.id) if pm_mapping
      end
    end

    def self.copy_versions(versions_mapping)
      return if versions_mapping.blank?
      versions_mapping.each_pair do |original, copy|
        log = Version.find(original).dup
        log.team_id = @copy_team.id
        log.is_being_copied = true
        log.associated_id = copy.id unless log.associated_id.blank?
        item = @mapping.dig(log.item_type.to_sym, log.item_id.to_i)
        self.update_version_fields(log, item)
        log.save(validate: false)
      end
    end

    def self.update_version_fields(log, item)
      return unless item
      self.update_version_object(log, item)
      self.update_version_object_changes(log)
      self.update_version_meta(log, item)
      log.item_id = item.id
      log.set_object_after
    end

    def self.update_version_object(log, item)
      object = log.get_object
      return if object.blank?
      object['id'] = item.id if object['id']
      object['annotated_id'] = item.annotated_id if object['annotated_id']
      log.object = object.to_json
    end

    def self.update_version_object_changes(log)
      changes = log.get_object_changes.with_indifferent_access
      return if changes.blank?
      associations = { annotated_id: 'associated_type', source_id: 'associated_type', target_id: 'associated_type', id: 'item_type' }
      associations.each_pair do |field, method|
        unless changes[field].blank?
          changes[field].map! do |a|
            c = @mapping.dig(log.send(method).to_sym, a)
            c ? c.id : a
          end
        end
      end
      log.object_changes = changes.to_json
    end

    def self.update_version_meta(log, item)
      return if log.meta.blank?
      meta = JSON.parse(log.meta)
      if meta.dig('target', 'url') && item.target
        meta['target']['url'] = item.target.full_url
      end
      log.meta = meta.to_json
    end

    def self.create_copy_version(pm_mapping, user)
      return if pm_mapping.blank? || user.nil?
      pm_mapping.each_pair do |_original, copy|
        v = Version.new
        v.item_id, v.item_type = copy.id, copy.class_name
        v.associated_id, v.associated_type = copy.id, copy.class_name
        v.event = 'copy'
        changes = {}
        changes['team_id'] = [@original_team.id, @copy_team.id]
        v.whodunnit = user.id
        v.object_changes = changes.to_json
        v.save(validate: false)
      end
    end

    def self.update_cloned_versions(versions)
      versions.each do |version|
        self.update_version_fields(version, version.item)
        version.save(validate: false)
      end
    end

    def self.update_project_medias
      return if @mapping[:ProjectMedia].blank?
      @mapping[:ProjectMedia].each_value do |copy|
        copy.update_column(:team_id, @copy_team.id)
      end
    end

    def self.update_project_media_projects
      return if @mapping[:ProjectMediaProject].blank?
      @mapping[:ProjectMediaProject].each_value do |copy|
        pm_mapping = @mapping.dig(:ProjectMedia, copy.send(:project_media_id))
        copy.update_column(:project_media_id, pm_mapping.id) if pm_mapping
      end
    end
  end

  def generate_copy_slug
    i = 1
    slug = ''
    loop do
      slug = self.slug + "-copy-#{i}"
      if slug.length > 63
        extra = slug.length - 63
        slug.remove!(slug[11..10+extra])
      end
      break unless Team.find_by(slug: slug)
      i += 1
    end
    slug
  end
end
