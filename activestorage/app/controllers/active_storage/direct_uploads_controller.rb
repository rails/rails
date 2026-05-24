# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  # The blob attributes returned in the direct-upload JSON response. This is a
  # controller response contract shared by the default Active Record blob class
  # and custom backend blob classes; custom backends are not required to
  # implement Active Record's +as_json(root:, methods:)+.
  DIRECT_UPLOAD_BLOB_ATTRIBUTES = %i[
    id
    key
    filename
    content_type
    metadata
    service_name
    byte_size
    checksum
    created_at
  ].freeze

  def create
    blob = ActiveStorage.blob_class.create_before_direct_upload!(**blob_args)
    render json: direct_upload_json(blob)
  end

  private
    def blob_args
      params.expect(blob: [:filename, :byte_size, :checksum, :content_type, metadata: {}]).to_h.symbolize_keys.tap do |args|
        args[:metadata] = ActiveStorage.filter_blob_metadata(args[:metadata])
      end
    end

    def direct_upload_json(blob)
      blob_json(blob).merge(
        direct_upload: {
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload
        }
      )
    end

    # Backend-neutral projection: the same explicit shape is built for the
    # default Active Record blob class and for custom backend blobs, so there is
    # no need to special-case the persistence type. +Filename#as_json+ and
    # +Time#as_json+ render +filename+ and +created_at+ as the JSON strings the
    # response has always used.
    def blob_json(blob)
      DIRECT_UPLOAD_BLOB_ATTRIBUTES.index_with { |attribute| blob.public_send(attribute) }
        .merge(signed_id: blob.signed_id)
        .as_json
    end
end
