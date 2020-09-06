# frozen_string_literal: true

require 'action_view/helpers/tags/checkable'

module ActionView
  module Helpers
    module Tags # :nodoc:
      class RadioButton < Base # :nodoc:
        include Checkable

        def initialize(object_name, method_name, template_object, tag_value, options)
          @tag_value = tag_value
          super(object_name, method_name, template_object, options)
        end

        def render
          options = @options.stringify_keys
          options['type']     = 'radio'
          options['value']    = @tag_value
          options['checked'] = 'checked' if input_checked?(options)
          add_default_name_and_id_for_value(@tag_value, options)
          tag('input', options)
        end

        private
          def checked?(value)
            value.to_s == @tag_value.to_s
          end
      end
    end
  end
end
