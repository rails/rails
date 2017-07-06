require "action_controller"
require "active_storage/blob"
require "active_storage/verified_key_with_expiration"

require "active_support/core_ext/object/inclusion"

class ActiveStorage::DiskController < ActionController::Base
  def show
    if key = decode_verified_key
      blob = ActiveStorage::Blob.find_by!(key: key)
      
      if stale?(etag: blob.checksum)
        send_data blob.download, filename: blob.filename, type: blob.content_type, disposition: disposition_param
      end
    else
      head :not_found
    end
  end

  private
    def decode_verified_key
      ActiveStorage::VerifiedKeyWithExpiration.decode(params[:encoded_key])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || 'inline'
    end
end
