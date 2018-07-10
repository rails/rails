# frozen_string_literal: true

module ActiveStorage
  # Decorated proxy object representing of multiple attachments to a model.
  class Attached::Many < Attached
    delegate_missing_to :attachments

    # Returns all the associated attachment records.
    #
    # All methods called on this proxy object that aren't listed here will automatically be delegated to +attachments+.
    def attachments
      change.present? ? change.attachments : record.public_send("#{name}_attachments")
    end

    # Associates one or several attachments with the current record, saving them to the database.
    #
    #   document.images.attach(params[:images]) # Array of ActionDispatch::Http::UploadedFile objects
    #   document.images.attach(params[:signed_blob_id]) # Signed reference to blob from direct upload
    #   document.images.attach(io: File.open("/path/to/racecar.jpg"), filename: "racecar.jpg", content_type: "image/jpg")
    #   document.images.attach([ first_blob, second_blob ])
    def attach(*attachables)
      attachables.flatten.collect do |attachable|
        if record.new_record?
          attachments.build(record: record, blob: create_blob_from(attachable))
        else
          attachments.create!(record: record, blob: create_blob_from(attachable))
        end
      end
    end

    # Returns true if any attachments has been made.
    #
    #   class Gallery < ApplicationRecord
    #     has_many_attached :photos
    #   end
    #
    #   Gallery.new.photos.attached? # => false
    def attached?
      attachments.any?
    end

    # Deletes associated attachments without purging them, leaving their respective blobs in place.
    def detach
      attachments.destroy_all if attached?
    end

    ##
    # :method: purge
    #
    # Directly purges each associated attachment (i.e. destroys the blobs and
    # attachments and deletes the files on the service).

    ##
    # :method: purge_later
    #
    # Purges each associated attachment through the queuing system.
  end
end
