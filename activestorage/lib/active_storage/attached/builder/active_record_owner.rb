# frozen_string_literal: true

class ActiveStorage::Attached::Builder::ActiveRecordOwner # :nodoc:
  attr_reader :model

  # Tracks owner classes by name rather than by class object, so reloadable
  # Active Record classes are not retained across code reloads. Names are
  # resolved on read and filtered to classes that still declare attachments, so
  # a stale registry entry (a removed or reloaded class) cannot produce a false
  # HybridConfigurationError.
  def self.declared_classes
    declared_class_registry.keys.filter_map do |name|
      klass = name&.safe_constantize
      klass if klass.respond_to?(:attachment_reflections) && klass.attachment_reflections.any?
    end
  end

  def self.declared_class_registry
    @declared_class_registry ||= Concurrent::Map.new
  end

  def initialize(model)
    @model = model
  end

  def build_one(name, dependent:, service:, strict_loading:, analyze:, &block)
    refuse_if_storage_mismatch!
    track_declaration
    ActiveStorage::Attached::Model.validate_service_configuration(service, model, name) unless service.is_a?(Proc)

    model.generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
      # frozen_string_literal: true
      def #{name}
        @active_storage_attached ||= {}
        @active_storage_attached[:#{name}] ||= ActiveStorage::Attached::One.new("#{name}", self)
      end

      def #{name}=(attachable)
        attachment_changes["#{name}"] =
          if attachable.nil? || attachable == ""
            ActiveStorage::Attached::Changes::DeleteOne.new("#{name}", self)
          else
            ActiveStorage::Attached::Changes::CreateOne.new("#{name}", self, attachable)
          end
      end
    CODE

    model.has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
    model.has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

    model.scope :"with_attached_#{name}", -> {
      if ActiveStorage.track_variants
        includes("#{name}_attachment": { blob: {
          variant_records: { image_attachment: :blob },
          preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }
        } })
      else
        includes("#{name}_attachment": :blob)
      end
    }

    model.before_validation { attachment_changes[name.to_s]&.analyze }

    model.after_save { attachment_changes[name.to_s]&.save }

    model.after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }

    reflection = ActiveRecord::Reflection.create(
      :has_one_attached,
      name,
      nil,
      { dependent: dependent, service_name: service, analyze: analyze },
      model
    )
    yield reflection if block
    ActiveRecord::Reflection.add_attachment_reflection(model, name, reflection)
  end

  def build_many(name, dependent:, service:, strict_loading:, analyze:, &block)
    refuse_if_storage_mismatch!
    track_declaration
    ActiveStorage::Attached::Model.validate_service_configuration(service, model, name) unless service.is_a?(Proc)

    model.generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
      # frozen_string_literal: true
      def #{name}
        @active_storage_attached ||= {}
        @active_storage_attached[:#{name}] ||= ActiveStorage::Attached::Many.new("#{name}", self)
      end

      def #{name}=(attachables)
        attachables = Array(attachables).compact_blank
        pending_uploads = attachment_changes["#{name}"].try(:pending_uploads)

        attachment_changes["#{name}"] = if attachables.none?
          ActiveStorage::Attached::Changes::DeleteMany.new("#{name}", self)
        else
          ActiveStorage::Attached::Changes::CreateMany.new("#{name}", self, attachables, pending_uploads: pending_uploads)
        end
      end
    CODE

    model.has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
    model.has_many :"#{name}_blobs", through: :"#{name}_attachments", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

    model.scope :"with_attached_#{name}", -> {
      if ActiveStorage.track_variants
        includes("#{name}_attachments": { blob: {
          variant_records: { image_attachment: :blob },
          preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }
        } })
      else
        includes("#{name}_attachments": :blob)
      end
    }

    model.before_validation { attachment_changes[name.to_s]&.analyze }

    model.after_save { attachment_changes[name.to_s]&.save }

    model.after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }

    reflection = ActiveRecord::Reflection.create(
      :has_many_attached,
      name,
      nil,
      { dependent: dependent, service_name: service, analyze: analyze },
      model
    )
    yield reflection if block
    ActiveRecord::Reflection.add_attachment_reflection(model, name, reflection)
  end

  private
    def track_declaration
      self.class.declared_class_registry[model.name] = true
    end

    def refuse_if_storage_mismatch!
      blob_name = ActiveStorage.class_variable_get(:@@blob_class)
      attachment_name = ActiveStorage.class_variable_get(:@@attachment_class)
      variant_record_name = ActiveStorage.class_variable_get(:@@variant_record_class)

      return if blob_name == "ActiveStorage::Blob" &&
        attachment_name == "ActiveStorage::Attachment" &&
        variant_record_name == "ActiveStorage::VariantRecord"

      raise ActiveStorage::HybridConfigurationError, <<~MSG
        Cannot use Active Storage attachments on #{model.name}: #{model.name} is an ActiveRecord class, but non-default Active Storage storage classes are configured.

        ActiveStorage does not support mixing ActiveRecord owners with non-ActiveRecord storage classes.
      MSG
    end
end
