require "action_controller"
require "active_storage/blob"
require "active_storage/verified_key_with_expiration"

require "active_support/core_ext/object/inclusion"

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
