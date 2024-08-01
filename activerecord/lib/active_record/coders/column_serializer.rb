# frozen_string_literal: true

module ActiveRecord
  module Coders # :nodoc:
    class ColumnSerializer # :nodoc:
      attr_reader :object_class
      attr_reader :coder

      def initialize(attr_name, coder, object_class = Object)
        @attr_name = attr_name
        @object_class = object_class
        @coder = coder
        check_arity_of_constructor
      end

      def init_with(coder) # :nodoc:
        @attr_name = coder["attr_name"]
        @object_class = coder["object_class"]
        @coder = coder["coder"]
      end

      def dump(object)
        return if object.nil?

        assert_valid_value(object, action: "dump")
        coder.dump(object)
      end

      def load(payload)
        if payload.nil?
          if @object_class != ::Object
            return @object_class.new
          end
          return nil
        end

        object = coder.load(payload)

        assert_valid_value(object, action: "load")
        object ||= object_class.new if object_class != Object

        object
      end

      # Public because it's called by Type::Serialized
      def assert_valid_value(object, action:)
        unless object.nil? || object_class === object
          raise SerializationTypeMismatch,
            "can't #{action} `#{@attr_name}`: was supposed to be a #{object_class}, but was a #{object.class}. -- #{object.inspect}"
        end
      end

      private
        def check_arity_of_constructor
          load(nil)
        rescue ArgumentError
          raise ArgumentError, "Cannot serialize #{object_class}. Classes passed to `serialize` must have a 0 argument constructor."
        end
    end
  end
end
