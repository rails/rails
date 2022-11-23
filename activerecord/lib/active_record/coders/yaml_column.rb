# frozen_string_literal: true

require "yaml"

module ActiveRecord
  module Coders # :nodoc:
    class YAMLColumn # :nodoc:
      attr_accessor :object_class

      def initialize(attr_name, object_class = Object, permitted_classes: [], unsafe_load: nil)
        @attr_name = attr_name
        @object_class = object_class
        @permitted_classes = permitted_classes
        @unsafe_load = unsafe_load
        check_arity_of_constructor
      end

      def init_with(coder) # :nodoc:
        # This is just to avoid the warning about trying to use instance variables before defining them
        # when loading from an YAML generated in a Rails version before 7.1.
        #
        # This method can be removed when we drop support to Ruby 2.7.
        @attr_name = coder["attr_name"]
        @object_class = coder["object_class"]
        @permitted_classes = coder["permitted_classes"] || []
        @unsafe_load = coder["unsafe_load"]
      end

      def dump(obj)
        return if obj.nil?

        assert_valid_value(obj, action: "dump")
        YAML.dump obj
      end

      def load(yaml)
        return object_class.new if object_class != Object && yaml.nil?
        return yaml unless yaml.is_a?(String) && yaml.start_with?("---")
        obj = yaml_load(yaml)

        assert_valid_value(obj, action: "load")
        obj ||= object_class.new if object_class != Object

        obj
      end

      def assert_valid_value(obj, action:)
        unless obj.nil? || obj.is_a?(object_class)
          raise SerializationTypeMismatch,
            "can't #{action} `#{@attr_name}`: was supposed to be a #{object_class}, but was a #{obj.class}. -- #{obj.inspect}"
        end
      end

      private
        def permitted_classes
          # This `defined?` check is just to avoid the warning about trying to use instance variables before defining
          # them when loading from an Marshal object generated in a Rails version before 7.1.
          #
          # The `defined?` can be removed when we drop support to Ruby 2.7.
          if defined?(@permitted_classes)
            ActiveRecord.yaml_column_permitted_classes + @permitted_classes
          else
            ActiveRecord.yaml_column_permitted_classes
          end
        end

        def unsafe_load?
          # This `defined?` check is just to avoid the warning about trying to use instance variables before defining
          # them when loading from an Marshal object generated in a Rails version before 7.1.
          #
          # The `defined?` can be removed when we drop support to Ruby 2.7.
          defined?(@unsafe_load) && !@unsafe_load.nil? ? @unsafe_load : ActiveRecord.use_yaml_unsafe_load
        end

        def check_arity_of_constructor
          load(nil)
        rescue ArgumentError
          raise ArgumentError, "Cannot serialize #{object_class}. Classes passed to `serialize` must have a 0 argument constructor."
        end

        if YAML.respond_to?(:unsafe_load)
          def yaml_load(payload)
            if unsafe_load?
              YAML.unsafe_load(payload)
            else
              YAML.safe_load(payload, permitted_classes: permitted_classes, aliases: true)
            end
          end
        else
          def yaml_load(payload)
            if unsafe_load?
              YAML.load(payload)
            else
              YAML.safe_load(payload, permitted_classes: permitted_classes, aliases: true)
            end
          end
        end
    end
  end
end
