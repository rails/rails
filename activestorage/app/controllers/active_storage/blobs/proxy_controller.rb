# frozen_string_literal: true

# Take a signed permanent reference for a blob representation and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob and variation reference, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::Blobs::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders

  def show
    http_cache_forever(public: true) {}
    set_content_headers_from_blob(@blob)

    @blob.download do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end
