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
  # If the +:dependent+ option isn't set, all the attachments will be purged
  # (i.e. destroyed) whenever the record is destroyed.
  def has_many_attached(name, dependent: :purge_later)
    define_method(name) do
      instance_variable_get("@active_storage_attached_#{name}") ||
        instance_variable_set("@active_storage_attached_#{name}", ActiveStorage::Attached::Many.new(name, self))
    end

    if dependent == :purge_later
      before_destroy { public_send(name).purge_later }
    end
  end
end
