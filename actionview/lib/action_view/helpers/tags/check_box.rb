# frozen_string_literal: true

require 'action_view/helpers/tags/checkable'

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CheckBox < Base #:nodoc:
        include Checkable

        def initialize(object_name, method_name, template_object, checked_value, unchecked_value, options)
          @checked_value   = checked_value
          @unchecked_value = unchecked_value
          super(object_name, method_name, template_object, options)
        end

        def render
          options = @options.stringify_keys
          options['type']     = 'checkbox'
          options['value']    = @checked_value
          options['checked'] = 'checked' if input_checked?(options)

          if options['multiple']
            add_default_name_and_id_for_value(@checked_value, options)
            options.delete('multiple')
          else
            add_default_name_and_id(options)
          end

          include_hidden = options.delete('include_hidden') { true }
          checkbox = tag('input', options)

          if include_hidden
            hidden = hidden_field_for_checkbox(options)
            hidden + checkbox
          else
            checkbox
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
            @unchecked_value ? tag('input', options.slice('name', 'disabled', 'form').merge!('type' => 'hidden', 'value' => @unchecked_value)) : ''.html_safe
          end
      end
    end
  end
end
