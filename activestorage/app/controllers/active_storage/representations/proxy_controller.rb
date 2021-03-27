# frozen_string_literal: true

# Proxy files through application. This avoids having a redirect and makes files easier to cache.
class ActiveStorage::Representations::ProxyController < ActiveStorage::Representations::BaseController
  def show
    http_cache_forever public: true do
      send_blob_stream @representation.image
    end
  end
end
