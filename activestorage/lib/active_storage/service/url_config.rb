# frozen_string_literal: true

module ActiveStorage
  class Service::UrlConfig # :nodoc:
    delegate :host, :path, :user, :password, to: :uri

    def initialize(uri)
      @uri = uri
      @configuration_hash = build_url_hash.freeze
    end

    def fetch(key)
      @configuration_hash.fetch(:url).fetch(key)
    end

    def params
      fetch(:params)
    end

    private
      attr_reader :uri

      def build_url_hash
        service = uri.scheme && uri.scheme.tr("-", "_")
        params = Hash[(uri.query || "").split("&").map { |pair| pair.split("=", 2) }].symbolize_keys

        {
          url: {
            params: params,
            service: service,
            uri: uri
          }
        }
      end
  end
end
