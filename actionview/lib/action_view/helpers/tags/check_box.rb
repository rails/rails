# frozen_string_literal: true

require "action_view/helpers/tags/checkable"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CheckBox < Base # :nodoc:
        include Checkable

        def initialize(object_name, method_name, template_object, checked_value, unchecked_value, options)
          @checked_value   = checked_value
          @unchecked_value = unchecked_value
          super(object_name, method_name, template_object, options)
        end

        def to_s
          options = options_with_hidden_attribute

          include_hidden = options.delete("include_hidden") { true }
          checkbox = tag("input", options)

          if include_hidden
            hidden = hidden_field_for_checkbox(options)
            hidden + checkbox
          else
            checkbox
          end
        end

        def attributes
          options = options_with_hidden_attribute
          options.delete("include_hidden")
          options
        end

        def hidden_field_attributes
          options = options_with_hidden_attribute
          include_hidden = options.delete("include_hidden") { true }

          if include_hidden && @unchecked_value
            prepare_hidden_options(options)
          else
            {}
          end
        end

        private
          def checked?(value)
            case value
            when TrueClass, FalseClass
              value == !!@checked_value
            when NilClass
              false
            when String
              value == @checked_value
            else
              if value.respond_to?(:include?)
                value.include?(@checked_value)
              else
                value.to_i == @checked_value.to_i
              end
            end
          end

          def hidden_field_for_checkbox(options)
            if @unchecked_value
              tag("input", prepare_hidden_options(options))
            else
              "".html_safe
            end
          end

          def options_with_hidden_attribute
            options = @options.stringify_keys
            options["type"]     = "checkbox"
            options["value"]    = @checked_value
            options["checked"] = "checked" if input_checked?(options)

            if options["multiple"]
              add_default_name_and_field_for_value(@checked_value, options)
              options.delete("multiple")
            else
              add_default_name_and_field(options)
            end

            options
          end

          def prepare_hidden_options(options)
            tag_options = options.slice("name", "disabled", "form").merge!("type" => "hidden", "value" => @unchecked_value)
            tag_options["autocomplete"] = "off" unless ActionView::Base.remove_hidden_field_autocomplete
            tag_options
          end
      end
    end
  end
end
