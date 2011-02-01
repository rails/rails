module ActiveRecord
  # :stopdoc:
  module Coders
    class YAMLColumn
      RESCUE_ERRORS = [ ArgumentError ]

      if defined?(Psych) && defined?(Psych::SyntaxError)
        RESCUE_ERRORS << Psych::SyntaxError
      end

      attr_accessor :object_class

      def initialize(object_class = Object)
        @object_class = object_class
      end

      def dump(obj)
        YAML.dump obj
      end

      def load(yaml)
        return yaml unless yaml.is_a?(String) && yaml =~ /^---/
        begin
          obj = YAML.load(yaml)

          unless obj.is_a?(object_class) || obj.nil?
            raise SerializationTypeMismatch,
              "Attribute was supposed to be a #{object_class}, but was a #{obj.class}"
          end

          obj
        rescue *RESCUE_ERRORS
          yaml
        end
      end
    end
  end
  # :startdoc
end
