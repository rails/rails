require 'yaml'

module ActiveRecord
  module Coders # :nodoc:
    class YAMLColumn # :nodoc:
      RESCUE_ERRORS = [ ArgumentError, Psych::SyntaxError ]

      attr_accessor :object_class

      def initialize(object_class = Object)
        @object_class = object_class
      end

      def dump(obj)
        return if obj.nil?

        unless obj.is_a?(object_class)
          raise SerializationTypeMismatch,
            "Attribute was supposed to be a #{object_class}, but was a #{obj.class}. -- #{obj.inspect}"
        end
        YAML.dump obj
      end

      def load(yaml)
        return object_class.new if object_class != Object && yaml.nil?
        return yaml unless yaml.is_a?(String) && yaml =~ /^---/
        begin
          obj = YAML.load(yaml)

          unless obj.is_a?(object_class) || obj.nil?
            raise SerializationTypeMismatch,
              "Attribute was supposed to be a #{object_class}, but was a #{obj.class}"
          end
          obj ||= object_class.new if object_class != Object

          obj
        rescue *RESCUE_ERRORS
          yaml
        end
      end
    end
  end
end
