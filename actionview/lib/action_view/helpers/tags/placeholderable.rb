module ActionView
  module Helpers
    module Tags # :nodoc:
      module Placeholderable # :nodoc:
        def initialize(*)
          super

          if tag_value = @options[:placeholder]
            placeholder = tag_value if tag_value.is_a?(String)

            object_name = @object_name.gsub(/\[(.*)_attributes\]\[\d+\]/, '.\1')
            method_and_value = tag_value.is_a?(TrueClass) ? @method_name : "#{@method_name}.#{tag_value}"

            if object.respond_to?(:to_model)
              key = object.class.model_name.i18n_key
              i18n_default = ["#{key}.#{method_and_value}".to_sym, ""]
            end

            i18n_default ||= ""
            placeholder ||= I18n.t("#{object_name}.#{method_and_value}", :default => i18n_default, :scope => "helpers.placeholder").presence

            placeholder ||= if object && object.class.respond_to?(:human_attribute_name)
                          object.class.human_attribute_name(method_and_value)
                        end

            placeholder ||= @method_name.humanize

            @options[:placeholder] = placeholder
          end
        end
      end
    end
  end
end
