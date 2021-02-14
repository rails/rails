# frozen_string_literal: true

# Proxy files through application. This avoids having a redirect and makes files easier to cache.
class ActiveStorage::Representations::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders

  def show
    http_cache_forever public: true do
      set_content_headers_from representation.image
      stream_from_storage representation
    end
  end

  private
    def representation
      @representation ||= @blob.representation(params[:variation_key]).processed
    end
end
