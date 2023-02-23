# frozen_string_literal: true

require "yaml"

module ActiveRecord
  module Coders # :nodoc:
    class YAMLColumn < ColumnSerializer # :nodoc:
      class SafeCoder
        def initialize(permitted_classes: [], unsafe_load: nil)
          @permitted_classes = permitted_classes
          @unsafe_load = unsafe_load
        end

        if Gem::Version.new(Psych::VERSION) >= Gem::Version.new("5.1")
          def dump(object)
            if @unsafe_load.nil? ? ActiveRecord.use_yaml_unsafe_load : @unsafe_load
              ::YAML.dump(object)
            else
              ::YAML.safe_dump(
                object,
                permitted_classes: @permitted_classes + ActiveRecord.yaml_column_permitted_classes,
                aliases: true,
              )
            end
          end
        else
          def dump(object)
            YAML.dump(object)
          end
        end

        if YAML.respond_to?(:unsafe_load)
          def load(payload)
            if @unsafe_load.nil? ? ActiveRecord.use_yaml_unsafe_load : @unsafe_load
              YAML.unsafe_load(payload)
            else
              YAML.safe_load(
                payload,
                permitted_classes: @permitted_classes + ActiveRecord.yaml_column_permitted_classes,
                aliases: true,
              )
            end
          end
        else
          def load(payload)
            if @unsafe_load.nil? ? ActiveRecord.use_yaml_unsafe_load : @unsafe_load
              YAML.load(payload)
            else
              YAML.safe_load(
                payload,
                permitted_classes: @permitted_classes + ActiveRecord.yaml_column_permitted_classes,
                aliases: true,
              )
            end
          end
        end
      end

      def initialize(attr_name, object_class = Object, permitted_classes: [], unsafe_load: nil)
        super(
          attr_name,
          SafeCoder.new(permitted_classes: permitted_classes || [], unsafe_load: unsafe_load),
          object_class,
        )
        check_arity_of_constructor
      end

      def init_with(coder) # :nodoc:
        unless coder["coder"]
          permitted_classes = coder["permitted_classes"] || []
          unsafe_load = coder["unsafe_load"] || false
          coder["coder"] = SafeCoder.new(permitted_classes: permitted_classes, unsafe_load: unsafe_load)
        end
        super(coder)
      end

      def coder
        # This is to retain forward compatibility when loading records serialized with Marshal
        # from a previous version of Rails.
        @coder ||= begin
          permitted_classes = defined?(@permitted_classes) ? @permitted_classes : []
          unsafe_load = defined?(@unsafe_load) && @unsafe_load.nil?
          SafeCoder.new(permitted_classes: permitted_classes, unsafe_load: unsafe_load)
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
