# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      module Placeholderable # :nodoc:
        def initialize(*)
          super

          if tag_value = @options[:placeholder]
            if tag_value.is_a?(String) || tag_value.is_a?(Integer)
              @options[:placeholder] = tag_value
            else
              # Handle TrueClass and Symbol for I18n translation
              method_and_value = tag_value.is_a?(TrueClass) ? @method_name : "#{@method_name}.#{tag_value}"

              placeholder = Tags::Translator
                .new(object, @object_name, method_and_value, scope: "helpers.placeholder")
                .translate
              placeholder ||= @method_name.humanize
              @options[:placeholder] = placeholder
            end
          end
        end
      end
    end
  end
end
