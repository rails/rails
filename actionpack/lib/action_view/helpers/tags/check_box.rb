require 'action_view/helpers/tags/checkable'

module ActionView
  module Helpers
    module Tags
      class CheckBox < Base #:nodoc:
        include Checkable

        def initialize(object_name, method_name, template_object, checked_value, unchecked_value, options)
          @checked_value   = checked_value
          @unchecked_value = unchecked_value
          super(object_name, method_name, template_object, options)
        end

        def render
          options = @options.stringify_keys
          options["type"]     = "checkbox"
          options["value"]    = @checked_value
          options["checked"] = "checked" if input_checked?(object, options)

          if options["multiple"]
            add_default_name_and_id_for_value(@checked_value, options)
            options.delete("multiple")
          else
            add_default_name_and_id(options)
          end

          hidden = @unchecked_value ? tag("input", "name" => options["name"], "type" => "hidden", "value" => @unchecked_value, "disabled" => options["disabled"]) : ""
          checkbox = tag("input", options)
          hidden + checkbox
        end

        private

        def checked?(value)
          case value
          when TrueClass, FalseClass
            value
          when NilClass
            false
          when Integer
            value != 0
          when String
            value == @checked_value
          when Array
            value.include?(@checked_value)
          else
            value.to_i != 0
          end
        end
      end
    end
  end
end
