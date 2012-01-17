module ActionView
  module Helpers
    module Tags
      class RadioButton < Base #:nodoc:
        def initialize(object_name, method_name, template_object, tag_value, options)
          @tag_value = tag_value
          super(object_name, method_name, template_object, options)
        end

        def render
          options = @options.stringify_keys
          options["type"]     = "radio"
          options["value"]    = @tag_value

          if options.has_key?("checked")
            cv = options.delete "checked"
            checked = cv == true || cv == "checked"
          else
            checked = radio_button_checked?(value(object))
          end

          options["checked"]  = "checked" if checked
          add_default_name_and_id_for_value(@tag_value, options)
          tag("input", options)
        end

        private

        def radio_button_checked?(value)
          value.to_s == @tag_value.to_s
        end
      end
    end
  end
end
