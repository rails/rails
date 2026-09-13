# frozen_string_literal: true

class ActiveStorage::Attached::Builder::Generic # :nodoc:
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def build_one(name, dependent:, service:, strict_loading:, analyze:, &block)
    validate_contract!
    refuse_if_storage_mismatch!
    validate_strict_loading!(strict_loading)
    install_reflection_extensions
    validate_service_configuration(service, name)
    define_one_accessors(name)
    install_callbacks(name)

    reflection = ActiveStorage::Reflection::ActiveModelHasOneAttachedReflection.new(
      model,
      name,
      { dependent: dependent, service_name: service, analyze: analyze }
    )
    yield reflection if block
    add_attachment_reflection(name, reflection)
  end

  def build_many(name, dependent:, service:, strict_loading:, analyze:, &block)
    validate_contract!
    refuse_if_storage_mismatch!
    validate_strict_loading!(strict_loading)
    install_reflection_extensions
    validate_service_configuration(service, name)
    define_many_accessors(name)
    install_callbacks(name)

    reflection = ActiveStorage::Reflection::ActiveModelHasManyAttachedReflection.new(
      model,
      name,
      { dependent: dependent, service_name: service, analyze: analyze }
    )
    yield reflection if block
    add_attachment_reflection(name, reflection)
  end

  private
    def validate_contract!
      unless model.respond_to?(:set_callback)
        raise ActiveStorage::OwnerContractMissing, "#{model.name} declares Active Storage attachments but does not support callbacks. Add `extend ActiveModel::Callbacks`."
      end

      {
        _save_callbacks: [ "save callbacks", "define_model_callbacks :save" ],
        _destroy_callbacks: [ "destroy callbacks", "define_model_callbacks :destroy" ],
        _validation_callbacks: [ "validation callbacks", "include ActiveModel::Validations::Callbacks" ],
      }.each do |chain, (description, fix)|
        unless model.send(:respond_to?, chain, true)
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
      warn_without_commit_callbacks
    end

    # The generated accessors store the owner's +id+ as the attachment
    # +record_id+ and gate attachment lookup and dependent cleanup on
    # +persisted?+ (see #define_one_accessors and #install_callbacks). An owner
    # missing +#id+, or relying on the default ActiveModel::API#persisted?
    # (which always returns false), would declare attachments successfully yet
    # silently fail at runtime: saved attachments would never be loaded and
    # destroy would never clean them up. Fail loudly at declaration time
    # instead.
    def validate_identity_contract!
      unless model.method_defined?(:id) || model.private_method_defined?(:id)
        raise ActiveStorage::OwnerContractMissing,
          "#{model.name} declares Active Storage attachments but does not define `#id`. " \
          "Active Storage stores it as the attachment `record_id` and reads it back to load and clean up attachments."
      end

      unless model.method_defined?(:persisted?) || model.private_method_defined?(:persisted?)
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
      return if model.send(:respond_to?, :_commit_callbacks, true)
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
      blob_name = ActiveStorage.class_variable_get(:@@blob_class)
      attachment_name = ActiveStorage.class_variable_get(:@@attachment_class)
      variant_record_name = ActiveStorage.class_variable_get(:@@variant_record_class)

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

    def install_reflection_extensions
      model.include ActiveStorage::Reflection::Extensions unless model.included_modules.include?(ActiveStorage::Reflection::Extensions)
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
      model.class_eval <<-CODE, __FILE__, __LINE__ + 1
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
      model.class_eval <<-CODE, __FILE__, __LINE__ + 1
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

    def install_callbacks(name)
      model.set_callback :validation, :before do
        attachment_changes[name.to_s]&.analyze
      end

      model.set_callback :save, :after do
        change = attachment_changes[name.to_s]
        next unless change

        change.save

        unless self.class.send(:respond_to?, :_commit_callbacks, true)
          attachment_changes.delete(name.to_s)
          change.upload if change.respond_to?(:upload)
          change.flush_deferred_purges if change.respond_to?(:flush_deferred_purges)
        end
      end

      if model.send(:respond_to?, :_commit_callbacks, true)
        model.set_callback :commit, :after do
          change = attachment_changes.delete(name.to_s)
          next unless change

          change.upload if change.respond_to?(:upload)
          change.flush_deferred_purges if change.respond_to?(:flush_deferred_purges)
        end
      end

      destroy_record_id_ivar = :"@active_storage_attached_#{name}_destroy_record_id"
      destroy_was_persisted_ivar = :"@active_storage_attached_#{name}_destroy_was_persisted"
      shared_destroy_purges_ivar = :@active_storage_destroy_deferred_purges
      reset_destroy_deferred_purges = ->(record) do
        record.instance_variable_set(shared_destroy_purges_ivar, nil)
      end

      # Destroys the persisted attachment rows for +name+ and returns the blob
      # purges deferred by their +dependent:+ option. Invoked from :destroy,
      # :after, and only for an owner that was persisted when the destroy began
      # and is gone once it ends -- so a halted destroy (which never reaches the
      # :after callbacks), a destroy that runs the chain to completion without
      # removing the owner (e.g. a backend +destroy+ that returns false instead
      # of `throw :abort`), and an unsaved owner whose preassigned id collides
      # with another record's rows are all filtered out. This mirrors the
      # transactional +dependent: :destroy+ used for Active Record owners without
      # relying on the backend providing a transaction. +record_id+ is captured
      # in :destroy, :before so cleanup targets the right rows even if the owner
      # clears its id while being destroyed.
      destroy_attachments_and_collect_purges = ->(record, record_id) do
        deferred_purges = []

        ActiveStorage.attachment_class.where(
          record_type: ActiveStorage::Attached::Changes.polymorphic_name(record),
          record_id: record_id,
          name: name.to_s
        ).each do |attachment|
          if deferred_purge = ActiveStorage::Attached::Changes.destroy_attachment(record, name.to_s, attachment)
            deferred_purges << deferred_purge
          end
        end

        deferred_purges
      end

      # True only for an owner that was persisted when its destroy began and no
      # longer is -- i.e. genuinely destroyed, not merely halted, vetoed, or
      # never saved (a preassigned id colliding with stored rows).
      owner_destroyed = ->(record) do
        record.instance_variable_get(destroy_was_persisted_ivar) && !record.persisted?
      end

      # Capture the owner id and whether it was persisted before any user-defined
      # before_destroy callback runs, so cleanup targets the right rows (even if
      # the owner blanks its id mid-destroy) and never deletes rows for an owner
      # that was never persisted.
      model.set_callback :destroy, :before, prepend: true do
        instance_variable_set(destroy_record_id_ivar, id)
        instance_variable_set(destroy_was_persisted_ivar, persisted?)
      end

      model.set_callback :destroy, :before do
        attachment_changes.delete(name.to_s)
      end

      # Install the shared-accumulator reset and the single flush once for the
      # whole class hierarchy (the callbacks are inherited; a subclass declaring
      # more attachments must not register duplicates). Every attachment name
      # collects its dependent purges into one owner-level accumulator that is
      # flushed through a single ActiveStorage::Attached::Changes.flush_pending_purges
      # call -- which purges each blob once -- so a blob shared across attachment
      # names is purged exactly once on destroy, on both the commit and the
      # non-commit paths.
      flush_installed = model.ancestors.any? do |ancestor|
        ancestor.is_a?(Class) && ancestor.instance_variable_defined?(:@active_storage_destroy_purge_flush_installed)
      end

      unless flush_installed
        model.instance_variable_set(:@active_storage_destroy_purge_flush_installed, true)

        model.set_callback :destroy, :before do
          reset_destroy_deferred_purges.call(self)
        end

        if model.send(:respond_to?, :_commit_callbacks, true)
          model.set_callback :commit, :after do
            deferred_purges = instance_variable_get(shared_destroy_purges_ivar)
            next if deferred_purges.nil? || deferred_purges.empty?

            # Only purge a genuinely destroyed owner's blobs. If the owner is
            # still persisted here, the destroy was rolled back and its rows
            # restored, so cancel the deferred purges instead of flushing them.
            # This also stops a stale purge from firing on a later, unrelated
            # commit when the owner cannot signal a rollback.
            if persisted?
              reset_destroy_deferred_purges.call(self)
              next
            end

            begin
              ActiveStorage::Attached::Changes.flush_pending_purges(deferred_purges)
            ensure
              reset_destroy_deferred_purges.call(self)
            end
          end

          if model.send(:respond_to?, :_rollback_callbacks, true)
            model.set_callback :rollback, :after do
              reset_destroy_deferred_purges.call(self)
            end
          end
        else
          # Without commit callbacks, flush immediately -- but only after every
          # attachment name's rows are destroyed. Registered before the per-name
          # collectors so it runs last among the reverse-ordered :destroy, :after
          # callbacks, ensuring a shared blob is purged once no row references it.
          model.set_callback :destroy, :after do
            deferred_purges = instance_variable_get(shared_destroy_purges_ivar)
            instance_variable_set(shared_destroy_purges_ivar, nil)
            ActiveStorage::Attached::Changes.flush_pending_purges(deferred_purges) if deferred_purges&.any?
          end
        end
      end

      model.set_callback :destroy, :after do
        next unless owner_destroyed.call(self)
        record_id = instance_variable_get(destroy_record_id_ivar)
        deferred_purges = destroy_attachments_and_collect_purges.call(self, record_id)
        next if deferred_purges.empty?

        accumulated = instance_variable_get(shared_destroy_purges_ivar) || []
        instance_variable_set(shared_destroy_purges_ivar, accumulated + deferred_purges)
      end
    end

    def add_attachment_reflection(name, reflection)
      model.attachment_reflections = model.attachment_reflections.merge(name.to_s => reflection)
    end
end
