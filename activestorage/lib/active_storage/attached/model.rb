# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveStorage
  # Provides the class-level DSL for declaring an Active Record model's attachments.
  module Attached::Model
    extend ActiveSupport::Concern

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
      # To avoid N+1 queries, you can include the attached blobs in your query like so:
      #
      #   User.with_attached_avatar
      #
      # Under the covers, this relationship is implemented as a +has_one+ association to a
      # ActiveStorage::Attachment record and a +has_one-through+ association to a
      # ActiveStorage::Blob record. These associations are available as +avatar_attachment+
      # and +avatar_blob+. But you shouldn't need to work with these associations directly in
      # most circumstances.
      #
      # The system has been designed to having you go through the ActiveStorage::Attached::One
      # proxy that provides the dynamic proxy to the associations and factory methods, like +attach+.
      #
      # If the +:dependent+ option isn't set, the attachment will be purged
      # (i.e. destroyed) whenever the record is destroyed.
      #
      # If you need the attachment to use a service which differs from the globally configured one,
      # pass the +:service+ option. For instance:
      #
      #   class User < ActiveRecord::Base
      #     has_one_attached :avatar, service: :s3
      #   end
      #
      # If you need to enable +strict_loading+ to prevent lazy loading of attachment,
      # pass the +:strict_loading+ option. You can do:
      #
      #   class User < ApplicationRecord
      #     has_one_attached :avatar, strict_loading: true
      #   end
      #
      def has_one_attached(name, dependent: :purge_later, service: nil, strict_loading: false)
        validate_service_configuration(name, service)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
          # frozen_string_literal: true
          def #{name}
            @active_storage_attached ||= {}
            @active_storage_attached[:#{name}] ||= ActiveStorage::Attached::One.new("#{name}", self)
          end

          def #{name}=(attachable)
            attachment_changes["#{name}"] =
              if attachable.nil?
                ActiveStorage::Attached::Changes::DeleteOne.new("#{name}", self)
              else
                ActiveStorage::Attached::Changes::CreateOne.new("#{name}", self, attachable)
              end
          end
        CODE

        has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy, strict_loading: strict_loading
        has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

        scope :"with_attached_#{name}", -> { includes("#{name}_attachment": :blob) }

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
      # To avoid N+1 queries, you can include the attached blobs in your query like so:
      #
      #   Gallery.where(user: Current.user).with_attached_photos
      #
      # Under the covers, this relationship is implemented as a +has_many+ association to a
      # ActiveStorage::Attachment record and a +has_many-through+ association to a
      # ActiveStorage::Blob record. These associations are available as +photos_attachments+
      # and +photos_blobs+. But you shouldn't need to work with these associations directly in
      # most circumstances.
      #
      # The system has been designed to having you go through the ActiveStorage::Attached::Many
      # proxy that provides the dynamic proxy to the associations and factory methods, like +#attach+.
      #
      # If the +:dependent+ option isn't set, all the attachments will be purged
      # (i.e. destroyed) whenever the record is destroyed.
      #
      # If you need the attachment to use a service which differs from the globally configured one,
      # pass the +:service+ option. For instance:
      #
      #   class Gallery < ActiveRecord::Base
      #     has_many_attached :photos, service: :s3
      #   end
      #
      # If you need to enable +strict_loading+ to prevent lazy loading of attachments,
      # pass the +:strict_loading+ option. You can do:
      #
      #   class Gallery < ApplicationRecord
      #     has_many_attached :photos, strict_loading: true
      #   end
      #
      def has_many_attached(name, dependent: :purge_later, service: nil, strict_loading: false)
        validate_service_configuration(name, service)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
          # frozen_string_literal: true
          def #{name}
            @active_storage_attached ||= {}
            @active_storage_attached[:#{name}] ||= ActiveStorage::Attached::Many.new("#{name}", self)
          end

          def #{name}=(attachables)
            if ActiveStorage.replace_on_assign_to_many
              attachment_changes["#{name}"] =
                if Array(attachables).none?
                  ActiveStorage::Attached::Changes::DeleteMany.new("#{name}", self)
                else
                  ActiveStorage::Attached::Changes::CreateMany.new("#{name}", self, attachables)
                end
            else
              ActiveSupport::Deprecation.warn \
                "config.active_storage.replace_on_assign_to_many is deprecated and will be removed in Rails 7.1. " \
                "Make sure that your code works well with config.active_storage.replace_on_assign_to_many set to true before upgrading. " \
                "To append new attachables to the Active Storage association, prefer using `attach`. " \
                "Using association setter would result in purging the existing attached attachments and replacing them with new ones."

              if Array(attachables).any?
                attachment_changes["#{name}"] =
                  ActiveStorage::Attached::Changes::CreateMany.new("#{name}", self, #{name}.blobs + attachables)
              end
            end
          end
        CODE

        has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy, strict_loading: strict_loading do
          def purge
            deprecate(:purge)
            each(&:purge)
            reset
          end

          def purge_later
            deprecate(:purge_later)
            each(&:purge_later)
            reset
          end

          private
          def deprecate(action)
            reflection_name = proxy_association.reflection.name
            attached_name = reflection_name.to_s.partition("_").first
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Calling `#{action}` from `#{reflection_name}` is deprecated and will be removed in Rails 7.1.
              To migrate to Rails 7.1's behavior call `#{action}` from `#{attached_name}` instead: `#{attached_name}.#{action}`.
            MSG
          end
        end
        has_many :"#{name}_blobs", through: :"#{name}_attachments", class_name: "ActiveStorage::Blob", source: :blob, strict_loading: strict_loading

        scope :"with_attached_#{name}", -> {
          if ActiveStorage.track_variants
            includes("#{name}_attachments": { blob: :variant_records })
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

      private
        def validate_service_configuration(association_name, service)
          if service.present?
            ActiveStorage::Blob.services.fetch(service) do
              raise ArgumentError, "Cannot configure service :#{service} for #{name}##{association_name}"
            end
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
