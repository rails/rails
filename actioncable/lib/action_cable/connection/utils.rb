module ActionCable
  module Connection
    module Utils # :nodoc:
      extend ActiveSupport::Concern

      # Parse the subscription's identifier, as well as
      # the connection's message data
      def parsed_json_data(json_data)
        data = json_to_hash(json_data)

        data['identifier'] = hash_to_json(data['identifier'])
        data['data'] = json_to_hash(data['data'])
        data
      end

      def hash_to_json(data)
        return unless data
        data = ActiveSupport::JSON.encode(data) if data.is_a?(Hash)
        data
      end

      def json_to_hash(data)
        return unless data
        data = ActiveSupport::JSON.decode(data) unless data.is_a?(Hash)
        data.with_indifferent_access
      end
    end
  end
end
