# Representation of a single attachment to a model.
class ActiveStorage::Attached::One < ActiveStorage::Attached
  delegate_missing_to :attachment

  # Returns the associated attachment record.
  #
  # You don't have to call this method to access the attachment's methods as
  # they are all available at the model level.
  def attachment
    record.public_send("#{name}_attachment")
  end

  # Associates a given attachment with the current record, saving it to the database.
  # Examples:
  #
  #   person.avatar.attach(params[:avatar]) # ActionDispatch::Http::UploadedFile object
  #   person.avatar.attach(params[:signed_blob_id]) # Signed reference to blob from direct upload
  #   person.avatar.attach(io: File.open("~/face.jpg"), filename: "face.jpg", content_type: "image/jpg")
  #   person.avatar.attach(avatar_blob) # ActiveStorage::Blob object
  def attach(attachable)
    write_attachment \
      ActiveStorage::Attachment.create!(record: record, name: name, blob: create_blob_from(attachable))
  end

  # Returns true if an attachment has been made.
  #
  #   class User < ActiveRecord::Base
  #     has_one_attached :avatar
  #   end
  #
  #   User.new.avatar.attached? # => false
  def attached?
    attachment.present?
  end

  # Directly purges the attachment (i.e. destroys the blob and
  # attachment and deletes the file on the service).
  def purge
    if attached?
      attachment.purge
      write_attachment nil
    end
  end

  # Purges the attachment through the queuing system.
  def purge_later
    if attached?
      attachment.purge_later
    end
  end

  private
    def write_attachment(attachment)
      record.public_send("#{name}_attachment=", attachment)
    end
end
