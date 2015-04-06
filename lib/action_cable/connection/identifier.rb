module ActionCable
  module Connection
    module Identifier

      def internal_redis_channel
        "action_cable/#{connection_identifier}"
      end

      def connection_identifier
        @connection_identifier ||= connection_gid identifiers.map { |id| instance_variable_get("@#{id}")}
      end

      def connection_gid(ids)
        ids.map {|o| o.to_global_id.to_s }.sort.join(":")
      end

    end
  end
end
