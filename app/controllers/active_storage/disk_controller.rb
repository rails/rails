# This controller is a wrapper around local file downloading. It allows you to
# make abstraction of the URL generation logic and to serve files with expiry
# if you are using the +Disk+ service.
#
# By default, mounting the Active Storage engine inside your application will
# define a +/rails/blobs/:encoded_key/*filename+ route that will reference this
# controller's +show+ action and will be used to serve local files.
#
# A URL for an attachment can be generated through its +#url+ method, that
# will use the aforementioned route.
class ActiveStorage::DiskController < ActionController::Base
  def show
    if key = decode_verified_key
      # FIXME: Find a way to set the correct content type
      send_data disk_service.download(key), filename: params[:filename], disposition: disposition_param
    else
      head :not_found
    end
  end

  private
    def disk_service
      ActiveStorage::Blob.service
    end

    def decode_verified_key
      ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end
end
