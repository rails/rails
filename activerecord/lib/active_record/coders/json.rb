module ActiveRecord
  module Coders # :nodoc:
    class JSON # :nodoc:
      def self.dump(obj)
        ActiveSupport::JSON.encode(obj)
      end

      def self.load(json)
        ActiveSupport::JSON.decode(json)
      end
    end
  end
end
