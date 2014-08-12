module ActiveRecord
  module Coders # :nodoc:
    class JSON # :nodoc:
      def self.serialize_for_database(obj)
        ActiveSupport::JSON.encode(obj)
      end

      def self.deserialize_from_database(json)
        ActiveSupport::JSON.decode(json)
      end
    end
  end
end
