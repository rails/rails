# frozen_string_literal: true

module ActiveStorage
  class Service::UrlConfig # :nodoc:
    def initialize(uri, configuration_hash = {})
      @uri = uri
      @configuration_hash = configuration_hash.merge(build_url_hash).freeze
    end

    def fetch(_)
      @configuration_hash.fetch(:url)
    end

    private
      attr_reader :uri

      def build_url_hash
        service = uri.scheme && uri.scheme.tr("-", "_")
        query_hash = Hash[(uri.query || "").split("&").map { |pair| pair.split("=", 2) }].symbolize_keys

        {
          url: {
            query_hash: query_hash,
            service: service,
            uri: uri
          }
        }
      end
  end
end