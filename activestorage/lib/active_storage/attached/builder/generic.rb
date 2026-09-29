# frozen_string_literal: true

# :markup: markdown

class ActiveStorage::Attached::Builder::Generic # :nodoc:
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def build_one(name, dependent:, service:, strict_loading:, analyze:, &block)
    prepare_model(name, service: service, strict_loading: strict_loading)
    define_one_accessors(name)

    reflection = ActiveStorage::Reflection::ActiveModelHasOneAttachedReflection.new(
      model,
      name,
      { dependent: dependent, service_name: service, analyze: analyze }
    )
    yield reflection if block
    add_attachment_reflection(name, reflection)
    ActiveStorage::Attached::Builder.register(model)
  end

  def build_many(name, dependent:, service:, strict_loading:, analyze:, &block)
    prepare_model(name, service: service, strict_loading: strict_loading)
    define_many_accessors(name)

    reflection = ActiveStorage::Reflection::ActiveModelHasManyAttachedReflection.new(
      model,
      name,
      { dependent: dependent, service_name: service, analyze: analyze }
    )
    yield reflection if block
    add_attachment_reflection(name, reflection)
    ActiveStorage::Attached::Builder.register(model)
  end

  private
    def prepare_model(name, service:, strict_loading:)
      validate_contract!
      refuse_if_storage_mismatch!
      validate_strict_loading!(strict_loading)
      model.include ActiveStorage::Reflection::Extensions
      validate_service_configuration(service, name)
      ActiveStorage::Attached::GenericLifecycle.install(model)
    end

    def validate_contract!
      unless model.respond_to?(:set_callback)
        raise ActiveStorage::OwnerContractMissing, "#{model.name} declares Active Storage attachments but does not support callbacks. Add `extend ActiveModel::Callbacks`."
      end

      {
        _save_callbacks: [ "save callbacks", "define_model_callbacks :save" ],
        _destroy_callbacks: [ "destroy callbacks", "define_model_callbacks :destroy" ],
        _validation_callbacks: [ "validation callbacks", "include ActiveModel::Validations::Callbacks" ],
      }.each do |chain, (description, fix)|
        unless model.respond_to?(chain, true)
          raise ActiveStorage::OwnerContractMissing,
            "#{model.name} declares Active Storage attachments but does not define #{description}. Add `#{fix}` to your owner class."
        end
      end

      unless model.respond_to?(:find)
        raise ActiveStorage::OwnerContractMissing,
          "#{model.name} declares Active Storage attachments but does not define a class method `.find(id)`. " \
          "Active Storage resolves owners with `record_type.constantize.find(record_id)`."
      end

      validate_identity_contract!
      unless model.name
        raise ActiveStorage::OwnerContractMissing, "Attachment owners must have a class name so stored attachments can resolve their owner."
      end
      warn_without_commit_callbacks
    end

    # Active Model's default persisted? silently disables attachment lookups
    # and dependent cleanup, even after the owner has been stored.
    def validate_identity_contract!
      unless model.public_method_defined?(:id)
        raise ActiveStorage::OwnerContractMissing,
          "#{model.name} declares Active Storage attachments but does not define `#id`. " \
          "Active Storage stores it as the attachment `record_id` and reads it back to load and clean up attachments."
      end

      unless model.public_method_defined?(:persisted?)
        raise ActiveStorage::OwnerContractMissing,
          "#{model.name} declares Active Storage attachments but does not define `#persisted?`. " \
          "Active Storage skips attachment lookups and dependent cleanup unless `persisted?` reflects backend existence."
      end

      if defined?(ActiveModel::API) && model.instance_method(:persisted?).owner == ActiveModel::API
        raise ActiveStorage::OwnerContractMissing,
          "#{model.name} relies on the default ActiveModel::API#persisted?, which always returns false. " \
          "Override `#persisted?` to reflect whether the record currently exists in the backend; otherwise " \
          "saved attachments are never loaded and destroy never cleans them up."
      end
    end

    def warn_without_commit_callbacks
      return if model.respond_to?(:_commit_callbacks, true)
      return if model.instance_variable_get(:@as_commit_warned)

      model.instance_variable_set(:@as_commit_warned, true)
      ActiveStorage.logger&.warn <<~MSG.squish
        [ActiveStorage] #{model.name} declares Active Storage attachments but does not define :commit callbacks.
        Service upload will fire in :after_save instead of :after_commit, meaning a failed transaction will not
        roll back the file upload. Define commit callbacks with `define_model_callbacks :commit` for
        transactional-upload semantics.
      MSG
    end

    def refuse_if_storage_mismatch!
      return unless ActiveStorage.class_configuration_loaded

      blob_name = ActiveStorage.blob_class_name
      attachment_name = ActiveStorage.attachment_class_name
      variant_record_name = ActiveStorage.variant_record_class_name

      return unless blob_name == "ActiveStorage::Blob" ||
        attachment_name == "ActiveStorage::Attachment" ||
        variant_record_name == "ActiveStorage::VariantRecord"

      raise ActiveStorage::HybridConfigurationError, <<~MSG
        Cannot use Active Storage attachments on #{model.name}: #{model.name} is not an ActiveRecord class, but ActiveStorage is configured to use the default ActiveRecord storage classes.

        Configure custom backend classes for all three slots:
          config.active_storage.blob_class
          config.active_storage.attachment_class
          config.active_storage.variant_record_class
      MSG
    end

    def validate_service_configuration(service, name)
      ActiveStorage::Attached::Model.validate_service_configuration(service, model, name) unless service.is_a?(Proc)
    end

    def validate_strict_loading!(strict_loading)
      if strict_loading
        raise ArgumentError,
          "strict_loading: true is not supported for non-ActiveRecord owners. " \
          "Generic owners do not maintain Active Record associations."
      end
    end

    def define_one_accessors(name)
      generated_attachment_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
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
          attachment_lifecycle.assigned(self, attachment_changes["#{name}"])
        end

        def #{name}_attachment
          if defined?(@#{name}_attachment)
            @#{name}_attachment
          elsif !persisted?
            @#{name}_attachment = nil
          else
            record_type = ActiveStorage::Attached::Changes.polymorphic_name(self)
            @#{name}_attachment = ActiveStorage.attachment_class.find_by(record_type: record_type, record_id: id, name: "#{name}")
          end
        end

        def #{name}_attachment=(attachment)
          @#{name}_attachment = attachment
        end

        def #{name}_blob
          if defined?(@#{name}_blob)
            @#{name}_blob
          else
            @#{name}_blob = #{name}_attachment&.blob
          end
        end

        def #{name}_blob=(blob)
          @#{name}_blob = blob
        end
      CODE

      define_eager_loading_method(name)
    end

    def define_many_accessors(name)
      generated_attachment_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        # frozen_string_literal: true
        def #{name}
          @active_storage_attached ||= {}
          @active_storage_attached[:#{name}] ||= ActiveStorage::Attached::Many.new("#{name}", self)
        end

        def #{name}=(attachables)
          attachables = Array(attachables).compact_blank

          attachment_changes["#{name}"] = if attachables.none?
            ActiveStorage::Attached::Changes::DeleteMany.new("#{name}", self)
          else
            ActiveStorage::Attached::Changes::CreateMany.new("#{name}", self, attachables)
          end
          attachment_lifecycle.assigned(self, attachment_changes["#{name}"])
        end

        def #{name}_attachments
          @#{name}_attachments ||= ActiveStorage::Attached::Collection.new(self, "#{name}")
        end

        def #{name}_attachments=(attachments)
          @#{name}_attachments = attachments
        end

        def #{name}_blobs
          @#{name}_blobs ||= ActiveStorage::Attached::BlobsCollection.new(self, "#{name}")
        end

        def #{name}_blobs=(blobs)
          @#{name}_blobs = blobs
        end
      CODE

      define_eager_loading_method(name)
    end

    def define_eager_loading_method(name)
      model_name = model.name
      model.define_singleton_method("with_attached_#{name}") do
        raise ActiveStorage::EagerLoadingNotSupported,
          "Eager loading Active Storage attachments is not supported for non-ActiveRecord owners. " \
          "Query #{ActiveStorage.attachment_class.name}.where(record_type: #{model_name.inspect}, name: #{name.to_s.inspect}, ...) directly."
      end
    end

    def generated_attachment_methods
      if model.const_defined?(:GeneratedAttachmentMethods, false)
        model.const_get(:GeneratedAttachmentMethods, false)
      else
        model.const_set(:GeneratedAttachmentMethods, Module.new).tap do |methods|
          model.include methods
          model.private_constant :GeneratedAttachmentMethods
        end
      end
    end

    def add_attachment_reflection(name, reflection)
      model.attachment_reflections = model.attachment_reflections.merge(name.to_s => reflection)
    end
end
