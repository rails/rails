module ActiveRecord
  module Coders # :nodoc:
    class Restricted # :nodoc:
      def initialize(coder, object_class)
        @coder = coder
        @object_class = object_class || Object
      end

      def serialize_for_database(obj)
        @coder.serialize_for_database validate!(obj)
      end

      def deserialize_from_database(raw_data)
        validate! @coder.deserialize_from_database(raw_data)
      end

      private
        def validate!(obj)
          unless obj.is_a?(@object_class)
            raise SerializationTypeMismatch,
              "Attribute was supposed to be a #{@object_class}, but was a #{obj.class}. -- #{obj.inspect}"
          end

          obj
        end
    end
  end
end
