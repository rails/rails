# Decorated proxy object representing of multiple attachments to a model.
class ActiveStorage::Attached::Many < ActiveStorage::Attached
  delegate_missing_to :attachments

  # Returns all the associated attachment records.
  #
  # All methods called on this proxy object that aren't listed here will automatically be delegated to `attachments`.
  def attachments
    record.public_send("#{name}_attachments")
  end

  # Associates one or several attachments with the current record, saving them to the database.
  # Examples:
  #
  #   document.images.attach(params[:images]) # Array of ActionDispatch::Http::UploadedFile objects
  #   document.images.attach(params[:signed_blob_id]) # Signed reference to blob from direct upload
  #   document.images.attach(io: File.open("~/racecar.jpg"), filename: "racecar.jpg", content_type: "image/jpg")
  #   document.images.attach([ first_blob, second_blob ])
  def attach(*attachables)
    attachables.flatten.collect do |attachable|
      attachments.create!(name: name, blob: create_blob_from(attachable))
    end
  end

  # Returns true if any attachments has been made.
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
