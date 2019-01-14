# frozen_string_literal: true

module ActiveStorage
  # Provides the class-level DSL for declaring an Active Record model's attachments.
  module Attached::Model
    extend ActiveSupport::Concern

    class_methods do
      # Specifies the relation between a single attachment and the model.
      #
      #   class User < ActiveRecord::Base
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
      def has_one_attached(name, dependent: :purge_later, service: nil)
        validate_service_configuration(name, service)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
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

        has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: :destroy
        has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob

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
        ActiveRecord::Reflection.add_attachment_reflection(self, name, reflection)
      end

      # Specifies the relation between multiple attachments and the model.
      #
      #   class Gallery < ActiveRecord::Base
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
      def has_many_attached(name, dependent: :purge_later, service: nil)
        validate_service_configuration(name, service)

        generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
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
              if Array(attachables).any?
                attachment_changes["#{name}"] =
                  ActiveStorage::Attached::Changes::CreateMany.new("#{name}", self, #{name}.blobs + attachables)
              end
            end
          end
        CODE

        has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: :destroy do
          def purge
            each(&:purge)
            reset
          end

          def purge_later
            each(&:purge_later)
            reset
          end
        end
        has_many :"#{name}_blobs", through: :"#{name}_attachments", class_name: "ActiveStorage::Blob", source: :blob

        scope :"with_attached_#{name}", -> { includes("#{name}_attachments": :blob) }

        after_save { attachment_changes[name.to_s]&.save }

        after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }

        reflection = ActiveRecord::Reflection.create(
          :has_many_attached,
          name,
          nil,
          { dependent: dependent, service_name: service },
          self
        )
        ActiveRecord::Reflection.add_attachment_reflection(self, name, reflection)
      end

      private
        def validate_service_configuration(association_name, service)
          return unless service

          ServiceRegistry.fetch(service) do
            raise ArgumentError, "Cannot configure service :#{service} for #{name}##{association_name}"
          end
        end
    end

    def attachment_changes #:nodoc:
      @attachment_changes ||= {}
    end

    def changed_for_autosave? #:nodoc:
      super || attachment_changes.any?
    end

    def initialize_dup(*) #:nodoc:
      super
      @active_storage_attached = nil
      @attachment_changes = nil
    end

    def reload(*) #:nodoc:
      super.tap { @attachment_changes = nil }
    end
  end
end
