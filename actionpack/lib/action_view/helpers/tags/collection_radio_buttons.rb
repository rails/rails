module ActionView
  module Helpers
    module Tags
      class CollectionRadioButtons < CollectionSelect
        delegate :radio_button, :label, :to => :@template_object

        def render
          rendered_collection = render_collection(
            @method_name, @collection, @value_method, @text_method, @options, @html_options
          ) do |value, text, default_html_options|
            if block_given?
              yield sanitize_attribute_name(@method_name, value), text, value, default_html_options
            else
              radio_button(@object_name, @method_name, value, default_html_options) +
                label(@object_name, sanitize_attribute_name(@method_name, value), text, :class => "collection_radio_buttons")
            end
          end

          wrap_rendered_collection(rendered_collection, @options)
        end

        private

        # Generate default options for collection helpers, such as :checked and
        # :disabled.
        def default_html_options_for_collection(item, value, options, html_options) #:nodoc:
          html_options = html_options.dup

          [:checked, :selected, :disabled].each do |option|
            next unless options[option]


            accept = if options[option].respond_to?(:call)
                       options[option].call(item)
                     else
                       Array(options[option]).include?(value)
                     end

            if accept
              html_options[option] = true
            elsif option == :checked
              html_options[option] = false
            end
          end

          html_options
        end

        def sanitize_attribute_name(attribute, value) #:nodoc:
          "#{attribute}_#{value.to_s.gsub(/\s/, "_").gsub(/[^-\w]/, "").downcase}"
        end

        def render_collection(attribute, collection, value_method, text_method, options={}, html_options={}) #:nodoc:
          item_wrapper_tag   = options.fetch(:item_wrapper_tag, :span)
          item_wrapper_class = options[:item_wrapper_class]

          collection.map do |item|
            value = value_for_collection(item, value_method)
            text  = value_for_collection(item, text_method)
            default_html_options = default_html_options_for_collection(item, value, options, html_options)

            rendered_item = yield value, text, default_html_options

            item_wrapper_tag ? @template_object.content_tag(item_wrapper_tag, rendered_item, :class => item_wrapper_class) : rendered_item
          end.join.html_safe
        end

        def value_for_collection(item, value) #:nodoc:
          value.respond_to?(:call) ? value.call(item) : item.send(value)
        end

        def wrap_rendered_collection(collection, options)
          wrapper_tag = options[:collection_wrapper_tag]

          if wrapper_tag
            wrapper_class = options[:collection_wrapper_class]
            @template_object.content_tag(wrapper_tag, collection, :class => wrapper_class)
          else
            collection
          end
        end
      end
    end
  end
end
