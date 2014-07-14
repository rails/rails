module ActiveRecord
  module Coders # :nodoc:
    class JSON # :nodoc:
      def self.dump(obj)
        ActiveSupport::JSON.encode(obj)
      end

      def self.load(json)
        ActiveSupport::JSON.decode(json) unless json.nil?
      end
    end
  end
end
