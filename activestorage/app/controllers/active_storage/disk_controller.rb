# frozen_string_literal: true

# Serves files stored with the disk service in the same way that the cloud services do.
# This means using expiring, signed URLs that are meant for immediate access, not permanent linking.
# Always go through the BlobsController, or your own authenticated controller, rather than directly
# to the service URL.
class ActiveStorage::DiskController < ActiveStorage::BaseController
  include ActiveStorage::FileServer

  skip_forgery_protection

  def show
    if key = decode_verified_key
      serve_file named_disk_service(key[:service_name]).path_for(key[:key]), content_type: key[:content_type], disposition: key[:disposition]
    else
      head :not_found
    end
  rescue Errno::ENOENT
    head :not_found
  end

  def update
    if token = decode_verified_token
      if acceptable_content?(token)
        named_disk_service(token[:service_name]).upload token[:key], request.body, checksum: token[:checksum]
      else
        head :unprocessable_entity
      end
    else
      head :not_found
    end
  rescue ActiveStorage::IntegrityError
    head :unprocessable_entity
  end

  private
    def named_disk_service(name)
      ActiveStorage::Blob.services.fetch(name) do
        ActiveStorage::Blob.service
      end
    end

    def decode_verified_key
      ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    end

    def decode_verified_token
      ActiveStorage.verifier.verified(params[:encoded_token], purpose: :blob_token)
    end

    def acceptable_content?(token)
      token[:content_type] == request.content_mime_type && token[:content_length] == request.content_length
    end
end
