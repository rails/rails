module ActionView
  module Helpers
    module Tags # :nodoc:
      class Label < Base # :nodoc:
        class LabelBuilder # :nodoc:
          attr_reader :object

          def initialize(template_object, object_name, method_name, object, tag_value)
            @template_object = template_object
            @object_name = object_name
            @method_name = method_name
            @object = object
            @tag_value = tag_value
          end

          def translation
            method_and_value = @tag_value.present? ? "#{@method_name}.#{@tag_value}" : @method_name
            @object_name.gsub!(/\[(.*)_attributes\]\[\d+\]/, '.\1')

            if object.respond_to?(:to_model)
              key = object.model_name.i18n_key
              i18n_default = ["#{key}.#{method_and_value}".to_sym, ""]
            end

            i18n_default ||= ""
            content = I18n.t("#{@object_name}.#{method_and_value}", :default => i18n_default, :scope => "helpers.label").presence

            content ||= if object && object.class.respond_to?(:human_attribute_name)
                          object.class.human_attribute_name(method_and_value)
                        end

            content ||= @method_name.humanize

            content
          end
        end

        def initialize(object_name, method_name, template_object, content_or_options = nil, options = nil)
          options ||= {}

          content_is_options = content_or_options.is_a?(Hash)
          if content_is_options
            options.merge! content_or_options
            @content = nil
          else
            @content = content_or_options
          end

          super(object_name, method_name, template_object, options)
        end

        def render(&block)
          options = @options.stringify_keys
          tag_value = options.delete("value")
          name_and_id = options.dup

          if name_and_id["for"]
            name_and_id["id"] = name_and_id["for"]
          else
            name_and_id.delete("id")
          end

          add_default_name_and_id_for_value(tag_value, name_and_id)
          options.delete("index")
          options.delete("namespace")
          options["for"] = name_and_id["id"] unless options.key?("for")

          builder = LabelBuilder.new(@template_object, @object_name, @method_name, @object, tag_value)

          content = if block_given?
            @template_object.capture(builder, &block)
          elsif @content.present?
            @content.to_s
          else
            render_component(builder)
          end

          label_tag(name_and_id["id"], content, options)
        end

        private

          def render_component(builder)
            builder.translation
          end
      end
    end
  end
end
