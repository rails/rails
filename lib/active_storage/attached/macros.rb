module ActiveStorage::Attached::Macros
  # Specifies the relation between a single attachment and the model.
  #
  #   class User < ActiveRecord::Base
  #     has_one_attached :avatar
  #   end
  #
  # There is no column defined on the model side, Active Storage takes
  # care of the mapping between your records and the attachment.
  #
  # If the +:dependent+ option isn't set, the attachment will be purged
  # (i.e. destroyed) whenever the record is destroyed.
  def has_one_attached(name, dependent: :purge_later)
    define_method(name) do
      instance_variable_get("@active_storage_attached_#{name}") ||
        instance_variable_set("@active_storage_attached_#{name}", ActiveStorage::Attached::One.new(name, self))
    end

    has_one :"#{name}_attachment", -> { where(name: name) }, class_name: "ActiveStorage::Attachment", as: :record
    has_one :"#{name}_blob", through: :"#{name}_attachment"

    if dependent == :purge_later
      before_destroy { public_send(name).purge_later }
    end
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
  # If the +:dependent+ option isn't set, all the attachments will be purged
  # (i.e. destroyed) whenever the record is destroyed.
  def has_many_attached(name, dependent: :purge_later)
    define_method(name) do
      instance_variable_get("@active_storage_attached_#{name}") ||
        instance_variable_set("@active_storage_attached_#{name}", ActiveStorage::Attached::Many.new(name, self))
    end

    has_many :"#{name}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment"
    has_many :"#{name}_blobs", through: :"#{name}_attachments"

    scope :"with_attached_#{name}", -> { includes("#{name}_attachments": :blob) }

    if dependent == :purge_later
      before_destroy { public_send(name).purge_later }
    end
  end
end
