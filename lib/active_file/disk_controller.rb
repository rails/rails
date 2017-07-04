require "action_controller"
require "active_file/blob"
require "active_file/verified_key_with_expiration"

require "active_support/core_ext/object/inclusion"

class ActiveFile::DiskController < ActionController::Base
  def show
    if key = decode_verified_key
      blob = ActiveFile::Blob.find_by!(key: key)
      
      if stale?(etag: blob.checksum)
        send_data blob.download, filename: blob.filename, type: blob.content_type, disposition: disposition_param
      end
    else
      head :not_found
    end
  end

  private
    def decode_verified_key
      ActiveFile::VerifiedKeyWithExpiration.decode(params[:encoded_key])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || 'inline'
    end
end
