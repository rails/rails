# frozen_string_literal: true

module ActiveStorage
  class DeliveryMethod::Proxy < DeliveryMethod
    def initialize(options = {})
      @options = {
        proxy_urls_expire_in: 1.year,
        proxy_urls_public: true,
        proxy_urls_host: nil
      }.merge(options)

      @options[:only_path] = true unless options[:proxy_urls_host]
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
