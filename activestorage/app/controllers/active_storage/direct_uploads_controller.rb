# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
#
# The blob's key starts with `config.active_storage.blob_prefix` and `config.active_storage.direct_upload_prefix`.
# To choose the prefix per request, for example to store each tenant's files in its own folder, subclass this
# controller and override `direct_upload_prefix`:
#
# ```
# class DirectUploadsController < ActiveStorage::DirectUploadsController
#   include Authentication
#
#   private
#     def direct_upload_prefix
#       [ super, Current.account.id ]
#     end
# end
# ```
#
# Then set `config.active_storage.draw_direct_upload_route = false` and route `rails_direct_uploads` to it:
#
# ```
# post "/rails/active_storage/direct_uploads" => "direct_uploads#create", as: :rails_direct_uploads
# ```
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
    render json: direct_upload_json(blob)
  end

  private
    def blob_args
      blob_params = params.expect(blob: [:filename, :byte_size, :checksum, :content_type, metadata: {}]).to_h.symbolize_keys
      blob_params.merge(key: ActiveStorage::Blob.generate_unique_key(prefix: direct_upload_prefix))
    end

    # The prefix for the keys of directly uploaded blobs, appended to `config.active_storage.blob_prefix`.
    # Can be a single value or an array of segments. Override it in a subclass to choose the prefix per request.
    def direct_upload_prefix
      ActiveStorage.direct_upload_prefix
    end

    def direct_upload_json(blob)
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      })
    end
end
