module ActionView
  module Helpers
    module Tags # :nodoc:
      module CollectionHelpers # :nodoc:
        class Builder # :nodoc:
          attr_reader :object, :text, :value

          def initialize(template_object, object_name, method_name, object,
                         sanitized_attribute_name, text, value, input_html_options)
            @template_object = template_object
            @object_name = object_name
            @method_name = method_name
            @object = object
            @sanitized_attribute_name = sanitized_attribute_name
            @text = text
            @value = value
            @input_html_options = input_html_options
          end

          def label(label_html_options={}, &block)
            html_options = @input_html_options.slice(:index, :namespace).merge(label_html_options)
            html_options[:for] ||= @input_html_options[:id] if @input_html_options[:id]

            @template_object.label(@object_name, @sanitized_attribute_name, @text, html_options, &block)
          end
        end

        def initialize(object_name, method_name, template_object, collection, value_method, text_method, options, html_options)
          @collection   = collection
          @value_method = value_method
          @text_method  = text_method
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        private

        def instantiate_builder(builder_class, item, value, text, html_options)
          builder_class.new(@template_object, @object_name, @method_name, item,
                            sanitize_attribute_name(value), text, value, html_options)
        end

        # Generate default options for collection helpers, such as :checked and
        # :disabled.
        def default_html_options_for_collection(item, value) #:nodoc:
          html_options = @html_options.dup

          [:checked, :selected, :disabled, :readonly].each do |option|
            current_value = @options[option]
            next if current_value.nil?

            accept = if current_value.respond_to?(:call)
              current_value.call(item)
            else
              Array(current_value).map(&:to_s).include?(value.to_s)
            end

            if accept
              html_options[option] = true
            elsif option == :checked
              html_options[option] = false
            end
          end

          html_options[:object] = @object
          html_options
        end

        def sanitize_attribute_name(value) #:nodoc:
          "#{sanitized_method_name}_#{sanitized_value(value)}"
        end

        def render_collection #:nodoc:
          @collection.map do |item|
            value = value_for_collection(item, @value_method)
            text  = value_for_collection(item, @text_method)
            default_html_options = default_html_options_for_collection(item, value)
            additional_html_options = option_html_attributes(item)

            yield item, value, text, default_html_options.merge(additional_html_options)
          end.join.html_safe
        end

        def render_collection_for(builder_class, &block) #:nodoc:
          options = @options.stringify_keys
          rendered_collection = render_collection do |item, value, text, default_html_options|
            builder = instantiate_builder(builder_class, item, value, text, default_html_options)

            if block_given?
              @template_object.capture(builder, &block)
            else
              render_component(builder)
            end
          end

          # Prepend a hidden field to make sure something will be sent back to the
          # server if all radio buttons are unchecked.
          if options.fetch('include_hidden', true)
            hidden_field + rendered_collection
          else
            rendered_collection
          end
        end

        def hidden_field #:nodoc:
          hidden_name = @html_options[:name] || hidden_field_name
          @template_object.hidden_field_tag(hidden_name, "", id: nil)
        end

        def hidden_field_name #:nodoc:
          "#{tag_name(false, @options[:index])}"
        end
      end
    end
  end
end
