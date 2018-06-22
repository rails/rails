# frozen_string_literal: true

module ActiveStorage
  # Provides the class-level DSL for declaring that an Active Record model has attached blobs.
  module Attached::Macros
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
    def has_one_attached(name, dependent: :purge_later)
      generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}
          @active_storage_attached_#{name} ||= ActiveStorage::Attached::One.new("#{name}", self, dependent: #{dependent == :purge_later ? ":purge_later" : "false"})
        end

        def #{name}=(attachable)
          #{name}.attach(attachable)
        end

        def #{name}_attached
          return #{name}.filename.to_s if #{name}.attached?
        end
      CODE

      has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: false
      has_one :"#{name}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob

      scope :"with_attached_#{name}", -> { includes("#{name}_attachment": :blob) }

      if dependent == :purge_later
        after_destroy_commit { public_send(name).purge_later }
      else
        before_destroy { public_send(name).detach }
      end

      ActiveRecord::Reflection.add_attachment_reflection(
        self,
        name,
        ActiveRecord::Reflection.create(:has_one_attached, name, nil, { dependent: dependent }, self)
      )
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
    def has_many_attached(name, dependent: :purge_later)
      generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}
          @active_storage_attached_#{name} ||= ActiveStorage::Attached::Many.new("#{name}", self, dependent: #{dependent == :purge_later ? ":purge_later" : "false"})
        end

        def #{name}=(attachables)
          #{name}.attach(attachables)
        end

        def #{name}_attached
          return #{name}.collect { |file| file.filename.to_s } if #{name}.attached?
        end
      CODE

      has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: false do
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

      if dependent == :purge_later
        after_destroy_commit { public_send(name).purge_later }
      else
        before_destroy { public_send(name).detach }
      end

      ActiveRecord::Reflection.add_attachment_reflection(
        self,
        name,
        ActiveRecord::Reflection.create(:has_many_attached, name, nil, { dependent: dependent }, self)
      )
    end

    # specifies which file fields will be added for serialization
    #
    # example
    # class Foo < ApplicationRecord
    #   has_one_attached :image
    #   has_many_attached :musics
    #   serialize_attachments :image, :musics
    # end

    def serialize_attachments(*attachments)
      generated_association_methods.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def as_json(options={})
          options[:methods] = #{attachments}.collect { |attachment| attachment.to_s+"_attached" }
          super
        end
      CODE
    end
  end
end
