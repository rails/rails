require "yaml"
require "active_support/core_ext/regexp"

module ActiveRecord
  module Coders # :nodoc:
    class YAMLColumn # :nodoc:

      attr_accessor :object_class

      def initialize(object_class = Object)
        @object_class = object_class
        check_arity_of_constructor
      end

      def dump(obj)
        return if obj.nil?

        assert_valid_value(obj)
        YAML.dump obj
      end

      def load(yaml)
        return object_class.new if object_class != Object && yaml.nil?
        return yaml unless yaml.is_a?(String) && /^---/.match?(yaml)
        obj = YAML.load(yaml)

        assert_valid_value(obj)
        obj ||= object_class.new if object_class != Object

        obj
      end

      def assert_valid_value(obj)
        unless obj.nil? || obj.is_a?(object_class)
          raise SerializationTypeMismatch,
            "Attribute was supposed to be a #{object_class}, but was a #{obj.class}. -- #{obj.inspect}"
        end
      end

      private

        def check_arity_of_constructor
          begin
            load(nil)
          rescue ArgumentError
            raise ArgumentError, "Cannot serialize #{object_class}. Classes passed to `serialize` must have a 0 argument constructor."
          end
        end
    end
  end
end
