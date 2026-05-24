# frozen_string_literal: true

class ActiveStorage::Attached::Builder::ActiveRecordOwner # :nodoc:
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def build_one(name, dependent:, service:, strict_loading:, analyze:, &block)
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
end
