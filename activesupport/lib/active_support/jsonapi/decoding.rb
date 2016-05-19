require 'jsonapi'

module ActiveSupport
  module JSONAPI
    class << self
      # Parses a JSON API string into a hash.
      # See http://jsonapi.org for more info.
      def decode(json)
        json = ActiveSupport::JSON.decode(json)
        data = ::JSONAPI.parse(json).data
        return {} if data.nil?
        hash = {}
        hash["id"] = data.id unless data.id.nil?
        hash["_type"] = data.type
        hash.merge!(data.attributes.to_hash)
        data.relationships.each do |name, rel|
          if rel.data.respond_to?(:each)
            hash["#{name.singularize}_ids"] = rel.data.map(&:id)
            hash["#{name.singularize}_types"] = rel.data.map { |val| val.type.singularize.capitalize }
          elsif !rel.data.nil?
            hash["#{name}_id"] = rel.data.id
            hash["#{name}_type"] = rel.data.type.singularize.capitalize
          else
            hash["#{name}_id"] = nil
          end
        end
        hash
      end

      # Returns the class of the error that will be raised when there is an
      # error in decoding the JSON API payload. Using this method means you
      # won't directly depend on the ActiveSupport's JSON API implementation, in
      # case it changes in the future.
      #
      #   begin
      #     obj = ActiveSupport::JSONAPI.decode(some_string)
      #   rescue ActiveSupport::JSONAPI.parse_error
      #     Rails.logger.warn("Attempted to decode invalid JSON API payload: #{some_string}")
      #   end
      def parse_error
        ::JSONAPI::InvalidDocument
      end
    end
  end
end
