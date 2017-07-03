# FIXME: To be used by DiskSite#url
class ActiveFile::DiskController < ActionController::Base
  def show
    if verified_key.expired?
      head :gone
    else
      blob = ActiveFile::Blob.find_by!(key: verified_key.to_s)
      send_data blob.download, filename: blob.filename, type: blob.content_type, disposition: disposition_param
    end
  end

  private
    def verified_key
      ActiveFile::Sites::DiskSite::VerifiedKeyWithExpiration.new(params[:id])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || 'inline'
    end
end
