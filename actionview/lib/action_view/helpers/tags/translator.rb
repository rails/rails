module ActionView
  module Helpers
    module Tags # :nodoc:
      class Translator # :nodoc:
        attr_reader :object, :object_name, :method_and_value, :i18n_scope

        def initialize(object, object_name, method_and_value, i18n_scope)
          @object = object
          @object_name = object_name.gsub(/\[(.*)_attributes\]\[\d+\]/, '.\1')
          @method_and_value = method_and_value
          @i18n_scope = i18n_scope
        end

        def call
          placeholder ||= I18n.t("#{object_name}.#{method_and_value}", :default => i18n_default, :scope => i18n_scope).presence
          placeholder || human_attribute_name
        end

        def i18n_default
          if model
            key = model.model_name.i18n_key
            ["#{key}.#{method_and_value}".to_sym, ""]
          else
            ""
          end
        end

        def human_attribute_name
          if model && model.class.respond_to?(:human_attribute_name)
            model.class.human_attribute_name(method_and_value)
          end
        end

        def model
          @model ||= object.to_model if object.respond_to?(:to_model)
        end
      end
    end
  end
end
