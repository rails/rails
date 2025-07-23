# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveStorage
  # = Active Storage \Attached \Model
  #
  # Provides the class-level DSL for declaring an Active Record model's attachments.
  module Attached::Model
    extend ActiveSupport::Concern

    ##
    # :method: *_attachment
    #
    # Returns the attachment for the +has_one_attached+.
    #
    #   User.last.avatar_attachment

    ##
    # :method: *_attachments
    #
    # Returns the attachments for the +has_many_attached+.
    #
    #   Gallery.last.photos_attachments

    ##
    # :method: *_blob
    #
    # Returns the blob for the +has_one_attached+ attachment.
    #
    #   User.last.avatar_blob

    ##
    # :method: *_blobs
    #
    # Returns the blobs for the +has_many_attached+ attachments.
    #
    #   Gallery.last.photos_blobs

    ##
    # :method: with_attached_*
    #
    # Includes the attached blobs in your query to avoid N+1 queries.
    #
    # If +ActiveStorage.track_variants+ is enabled, it will also include the
    # variants record and their attached blobs.
    #
    #   User.with_attached_avatar
    #
    # Use the plural form for +has_many_attached+:
    #
    #   Gallery.with_attached_photos

    class_methods do
      # Specifies the relation between a single attachment and the model.
      #
      #   class User < ApplicationRecord
      #     has_one_attached :avatar
      #   end
      #
      # There is no column defined on the model side, Active Storage takes
      # care of the mapping between your records and the attachment.
      #
      # Under the covers, this relationship is implemented as a +has_one+ association to an
      # ActiveStorage::Attachment record and a +has_one-through+ association to an
      # ActiveStorage::Blob record. These associations are available as +avatar_attachment+
      # and +avatar_blob+. But you shouldn't need to work with these associations directly in
      # most circumstances.
      #
      # Instead, +has_one_attached+ generates an ActiveStorage::Attached::One proxy to
      # provide access to the associations and factory methods, like +attach+:
      #
      #   user.avatar.attach(uploaded_file)
      #
      # The +:dependent+ option defaults to +:purge_later+. This means the attachment will be
      # purged (i.e. destroyed) in the background whenever the record is destroyed.
      # If an ActiveJob::Backend queue adapter is not set in the application set it to
      # +purge+ instead.
      #
      # If you need the attachment to use a service which differs from the globally configured one,
      # pass the +:service+ option. For example:
      #
      #   class User < ActiveRecord::Base
      #     has_one_attached :avatar, service: :s3
      #   end
      #
      # +:service+ can also be specified as a proc, and it will be called with the model instance:
      #
      #   class User < ActiveRecord::Base
      #     has_one_attached :avatar, service: ->(user) { user.in_europe_region? ? :s3_europe : :s3_usa }
      #   end
      #
      # To avoid N+1 queries, you can include the attached blobs in your query like so:
      #
      #   User.with_attached_avatar
      #
      # If you need to enable +strict_loading+ to prevent lazy loading of attachment,
      # pass the +:strict_loading+ option. You can do:
      #
      #   class User < ApplicationRecord
      #     has_one_attached :avatar, strict_loading: true
      #   end
      #
      # Note: Active Storage relies on polymorphic associations, which in turn store class names in the database.
      # When renaming classes that use <tt>has_one_attached</tt>, make sure to also update the class names in the
      # <tt>active_storage_attachments.record_type</tt> polymorphic type column of
      # the corresponding rows.
      def has_one_attached(name, dependent: :purge_later, service: nil, strict_loading: false)
        Attached::Model.validate_service_configuration(service, self, name) unless service.is_a?(Proc)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
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

        has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
        has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

        scope :"with_attached_#{name}", -> {
          if ActiveStorage.track_variants
            includes("#{name}_attachment": { blob: {
              variant_records: { image_attachment: :blob },
              preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }
            } })
          else
            includes("#{name}_attachment": :blob)
          end
        }

        after_save { attachment_changes[name.to_s]&.save }

        after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }

        reflection = ActiveRecord::Reflection.create(
          :has_one_attached,
          name,
          nil,
          { dependent: dependent, service_name: service },
          self
        )
        yield reflection if block_given?
        ActiveRecord::Reflection.add_attachment_reflection(self, name, reflection)
      end

      # Specifies the relation between multiple attachments and the model.
      #
      #   class Gallery < ApplicationRecord
      #     has_many_attached :photos
      #   end
      #
      # There are no columns defined on the model side, Active Storage takes
      # care of the mapping between your records and the attachments.
      #
      # Under the covers, this relationship is implemented as a +has_many+ association to an
      # ActiveStorage::Attachment record and a +has_many-through+ association to an
      # ActiveStorage::Blob record. These associations are available as +photos_attachments+
      # and +photos_blobs+. But you shouldn't need to work with these associations directly in
      # most circumstances.
      #
      # Instead, +has_many_attached+ generates an ActiveStorage::Attached::Many proxy to
      # provide access to the associations and factory methods, like +attach+:
      #
      #   user.photos.attach(uploaded_file)
      #
      # The +:dependent+ option defaults to +:purge_later+. This means the attachments will be
      # purged (i.e. destroyed) in the background whenever the record is destroyed.
      # If an ActiveJob::Backend queue adapter is not set in the application set it to
      # +purge+ instead.
      #
      # If you need the attachment to use a service which differs from the globally configured one,
      # pass the +:service+ option. For example:
      #
      #   class Gallery < ActiveRecord::Base
      #     has_many_attached :photos, service: :s3
      #   end
      #
      # +:service+ can also be specified as a proc, and it will be called with the model instance:
      #
      #   class Gallery < ActiveRecord::Base
      #     has_many_attached :photos, service: ->(gallery) { gallery.personal? ? :personal_s3 : :s3 }
      #   end
      #
      # To avoid N+1 queries, you can include the attached blobs in your query like so:
      #
      #   Gallery.where(user: Current.user).with_attached_photos
      #
      # If you need to enable +strict_loading+ to prevent lazy loading of attachments,
      # pass the +:strict_loading+ option. You can do:
      #
      #   class Gallery < ApplicationRecord
      #     has_many_attached :photos, strict_loading: true
      #   end
      #
      # Note: Active Storage relies on polymorphic associations, which in turn store class names in the database.
      # When renaming classes that use <tt>has_many</tt>, make sure to also update the class names in the
      # <tt>active_storage_attachments.record_type</tt> polymorphic type column of
      # the corresponding rows.
      def has_many_attached(name, dependent: :purge_later, service: nil, strict_loading: false)
        Attached::Model.validate_service_configuration(service, self, name) unless service.is_a?(Proc)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
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

        has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
        has_many :"#{name}_blobs", through: :"#{name}_attachments", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

        scope :"with_attached_#{name}", -> {
          if ActiveStorage.track_variants
            includes("#{name}_attachments": { blob: {
              variant_records: { image_attachment: :blob },
              preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }
            } })
          else
            includes("#{name}_attachments": :blob)
          end
        }

        after_save { attachment_changes[name.to_s]&.save }

        after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }

        reflection = ActiveRecord::Reflection.create(
          :has_many_attached,
          name,
          nil,
          { dependent: dependent, service_name: service },
          self
        )
        yield reflection if block_given?
        ActiveRecord::Reflection.add_attachment_reflection(self, name, reflection)
      end
    end

    class << self
      def validate_service_configuration(service_name, model_class, association_name) # :nodoc:
        if service_name
          ActiveStorage::Blob.services.fetch(service_name) do
            raise ArgumentError, "Cannot configure service #{service_name.inspect} for #{model_class}##{association_name}"
          end
        else
          validate_global_service_configuration(model_class)
        end
      end

      private
        def validate_global_service_configuration(model_class)
          if model_class.connected? && ActiveStorage::Blob.table_exists? && Rails.configuration.active_storage.service.nil?
            raise RuntimeError, "Missing Active Storage service name. Specify Active Storage service name for config.active_storage.service in config/environments/#{Rails.env}.rb"
          end
        end
    end

    def attachment_changes # :nodoc:
      @attachment_changes ||= {}
    end

    def changed_for_autosave? # :nodoc:
      super || attachment_changes.any?
    end

    def initialize_dup(*) # :nodoc:
      super
      @active_storage_attached = nil
      @attachment_changes = nil
    end

    def reload(*) # :nodoc:
      super.tap { @attachment_changes = nil }
    end
  end
end
