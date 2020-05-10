# frozen_string_literal: true

class ActiveStorage::Representations::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders

  def show
    http_cache_forever(public: true) {}
    representation = @blob.representation(params[:variation_key]).processed

    set_content_headers_from_blob(representation.image.blob)

    @blob.service.download(representation.key) do |chunk|
      response.stream.write(chunk)
    end
  ensure
    response.stream.close
  end
end
