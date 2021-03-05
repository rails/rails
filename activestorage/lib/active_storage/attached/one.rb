# frozen_string_literal: true

module ActiveStorage
  # Representation of a single attachment to a model.
  class Attached::One < Attached
    delegate_missing_to :attachment, allow_nil: true

    # Returns the associated attachment record.
    #
    # You don't have to call this method to access the attachment's methods as
    # they are all available at the model level.
    def attachment
      change.present? ? change.attachment : record.public_send("#{name}_attachment")
    end

    def blank?
      !attached?
    end

    # Attaches an +attachable+ to the record.
    #
    # If the record is persisted and unchanged, the attachment is saved to
    # the database immediately. Otherwise, it'll be saved to the DB when the
    # record is next saved.
    #
    #   person.avatar.attach(params[:avatar]) # ActionDispatch::Http::UploadedFile object
    #   person.avatar.attach(params[:signed_blob_id]) # Signed reference to blob from direct upload
    #   person.avatar.attach(io: File.open("/path/to/face.jpg"), filename: "face.jpg", content_type: "image/jpeg")
    #   person.avatar.attach(avatar_blob) # ActiveStorage::Blob object
    def attach(attachable)
      if record.persisted? && !record.changed?
        record.public_send("#{name}=", attachable)
        record.save
      else
        record.public_send("#{name}=", attachable)
      end
    end

    # Returns +true+ if an attachment has been made.
    #
    #   class User < ApplicationRecord
    #     has_one_attached :avatar
    #   end
    #
    #   User.new.avatar.attached? # => false
    def attached?
      attachment.present?
    end

    # Deletes the attachment without purging it, leaving its blob in place.
    def detach
      if attached?
        attachment.delete
        write_attachment nil
      end
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
        write_attachment nil
      end
    end

    private
      def write_attachment(attachment)
        record.public_send("#{name}_attachment=", attachment)
      end
  end
end
