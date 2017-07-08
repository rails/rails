# Representation of multiple attachments to a model.
class ActiveStorage::Attached::Many < ActiveStorage::Attached
  delegate_missing_to :attachments

  # Returns all the associated attachment records.
  #
  # You don't have to call this method to access the attachments' methods as
  # they are all available at the model level.
  def attachments
    @attachments ||= ActiveStorage::Attachment.where(record_gid: record.to_gid.to_s, name: name)
  end

  # Associates one or several attachments with the current record, saving
  # them to the database.
  def attach(*attachables)
    @attachments = attachments | Array(attachables).flatten.collect do |attachable|
      ActiveStorage::Attachment.create!(record_gid: record.to_gid.to_s, name: name, blob: create_blob_from(attachable))
    end
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
      @attachments = nil
    end
  end

  # Purges each associated attachment through the queuing system.
  def purge_later
    if attached?
      attachments.each(&:purge_later)
      @attachments = nil
    end
  end
end
