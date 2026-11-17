# frozen_string_literal: true

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

            content ||= Translator
              .new(object, @object_name, method_and_value, scope: "helpers.label")
              .translate
            content ||= @method_name.humanize

            content
          end

          def to_s
            translation
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

          add_default_name_and_field_for_value(tag_value, options, "for")
          options.delete("index")
          options.delete("name")
          options.delete("namespace")

          builder = LabelBuilder.new(@template_object, @object_name, @method_name, @object, tag_value)

          content = if block_given?
            @template_object.capture(builder, &block)
          elsif @content.present?
            @content.to_s
          else
            render_component(builder)
          end

          label_tag(options["for"], content, options)
        end

        private
          def render_component(builder)
            builder.translation
          end
      end
    end
  end
end
