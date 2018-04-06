# frozen_string_literal: true

# Serves files stored with the disk service in the same way that the cloud services do.
# This means using expiring, signed URLs that are meant for immediate access, not permanent linking.
# Always go through the BlobsController, or your own authenticated controller, rather than directly
# to the service url.
class ActiveStorage::DiskController < ActiveStorage::BaseController
  skip_forgery_protection

  def show
    if key = decode_verified_key
      send_data disk_service.download(key),
        disposition: params[:disposition], content_type: params[:content_type]
    else
      head :not_found
    end
  end

  def update
    if token = decode_verified_token
      if acceptable_content?(token)
        disk_service.upload token[:key], request.body, checksum: token[:checksum]
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
    def disk_service
      ActiveStorage::Blob.service
    end


    def decode_verified_key
      ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    end


    def decode_verified_token
      ActiveStorage.verifier.verified(params[:encoded_token], purpose: :blob_token)
    end

    def acceptable_content?(token)
      token[:content_type] == request.content_type && token[:content_length] == request.content_length
    end
end
