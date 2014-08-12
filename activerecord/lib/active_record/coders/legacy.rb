module ActiveRecord
  module Coders # :nodoc:
    class Legacy # :nodoc:
      def initialize(coder)
        @coder = coder
      end

      def serialize_for_database(obj)
        @coder.dump(obj)
      end

      def deserialize_from_database(raw_data)
        @coder.load(raw_data)
      end
    end
  end
end
