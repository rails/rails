# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod::Proxy < DeliveryMethod
    # * :host - Specifies the host the link should be targeted at.
    def initialize(options = {})
      @options = options

      @options[:only_path] = true unless options[:host]
    end

    def representation_url(representation, url_options: {})
      Rails.application.routes.url_helpers.route_for(
        :rails_blob_representation_proxy,
        representation.blob.signed_id,
        representation.variation.key,
        representation.blob.filename,
        @options.merge(url_options)
      )
    end

    def blob_url(signed_id, filename, url_options: {})
      Rails.application.routes.url_helpers.route_for(
        :rails_blob_proxy,
        signed_id,
        filename,
        @options.merge(url_options)
      )
    end
  end
end
