# frozen_string_literal: true

# Serves files stored with the disk service in the same way that the cloud services do.
# This means using expiring, signed URLs that are meant for immediate access, not permanent linking.
# Always go through the BlobsController, or your own authenticated controller, rather than directly
# to the service URL.
class ActiveStorage::DiskController < ActiveStorage::BaseController
  skip_forgery_protection

  def show
    if key = decode_verified_key
      serve_file private_disk_service.path_for(key[:key]), content_type: key[:content_type], disposition: key[:disposition]
    else
      head :not_found
    end
  rescue Errno::ENOENT
    head :not_found
  end

  def show_public
    key = params[:key]
    filename = File.basename(request.path)
    filepath = File.join(key, filename)

    if blob = ActiveStorage::Blob.find_by(key: key)
      if blob.public_file?
        serve_file public_disk_service.path_for(filepath), content_type: blob.content_type, disposition: :inline
      else
        head :unauthorized
      end
    else
      head :not_found
    end
  end

  def update
    if token = decode_verified_token
      if acceptable_content?(token)
        blob = ActiveStorage::Blob.find_by(key: token[:key])

        blob.service.upload token[:key], request.body, checksum: token[:checksum]
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
    def private_disk_service
      ActiveStorage::Blob.private_service
    end

    def public_disk_service
      ActiveStorage::Blob.public_service
    end

    def decode_verified_key
      ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    end

    def serve_file(path, content_type:, disposition:)
      Rack::File.new(nil).serving(request, path).tap do |(status, headers, body)|
        self.status = status
        self.response_body = body

        headers.each do |name, value|
          response.headers[name] = value
        end

        response.headers["Content-Type"] = content_type || DEFAULT_SEND_FILE_TYPE
        response.headers["Content-Disposition"] = disposition || DEFAULT_SEND_FILE_DISPOSITION
      end
    end


    def decode_verified_token
      ActiveStorage.verifier.verified(params[:encoded_token], purpose: :blob_token)
    end

    def acceptable_content?(token)
      token[:content_type] == request.content_mime_type && token[:content_length] == request.content_length
    end
end
