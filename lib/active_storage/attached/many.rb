# Representation of multiple attachments to a model.
class ActiveStorage::Attached::Many < ActiveStorage::Attached
  delegate_missing_to :attachments

  # Returns all the associated attachment records.
  #
  # You don't have to call this method to access the attachments' methods as
  # they are all available at the model level.
  def attachments
    record.public_send("#{name}_attachments")
  end

  # Associates one or several attachments with the current record, saving
  # them to the database.
  def attach(*attachables)
    record.public_send("#{name}_attachments=", attachments | Array(attachables).flat_map do |attachable|
      ActiveStorage::Attachment.create!(record: record, name: name, blob: create_blob_from(attachable))
    end)
  end

  # Checks the presence of attachments.
  #
  #   class Gallery < ActiveRecord::Base
  #     has_many_attached :photos
  #   end
  #
  #   Gallery.new.photos.attached? # => false
  def attached?
    attachments.any?
  end

  # Directly purges each associated attachment (i.e. destroys the blobs and
  # attachments and deletes the files on the service).
  def purge
    if attached?
      attachments.each(&:purge)
      attachments.reload
    end
  end

  # Purges each associated attachment through the queuing system.
  def purge_later
    if attached?
      attachments.each(&:purge_later)
    end
  end
end
