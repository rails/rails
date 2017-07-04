class ActiveFile::DiskController < ActionController::Base
  def show
    if key = decode_verified_key
      blob = ActiveFile::Blob.find_by!(key: key)
      send_data blob.download, filename: blob.filename, type: blob.content_type, disposition: disposition_param
    else
      head :not_found
    end
  end

  private
    def decode_verified_key
      ActiveFile::Site::DiskSite::VerifiedKeyWithExpiration.decode(params[:id])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || 'inline'
    end
end
