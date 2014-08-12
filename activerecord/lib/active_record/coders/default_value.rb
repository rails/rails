module ActiveRecord
  module Coders # :nodoc:
    class DefaultValue # :nodoc:
      def initialize(coder, object_class)
        @coder = coder
        @object_class = object_class unless object_class == Object
      end

      def serialize_for_database(obj)
        @coder.serialize_for_database(obj) unless obj.nil?
      end

      def deserialize_from_database(raw_data)
        obj = @coder.deserialize_from_database(raw_data) unless raw_data.nil?
        obj.nil? ? default_value : obj
      end

      private
        def default_value
          @object_class && @object_class.new rescue nil
        end
    end
  end
end
