module ActionView
  module Helpers
    module Tags
      class CollectionRadioButtons < CollectionSelect
        delegate :radio_button, :label, :to => :@template_object

        def render
          render_collection do |value, text, default_html_options|
            if block_given?
              yield sanitize_attribute_name(value), text, value, default_html_options
            else
              radio_button(@object_name, @method_name, value, default_html_options) +
                label(@object_name, sanitize_attribute_name(value), text, :class => "collection_radio_buttons")
            end
          end
        end

        private

        # Generate default options for collection helpers, such as :checked and
        # :disabled.
        def default_html_options_for_collection(item, value) #:nodoc:
          html_options = @html_options.dup

          [:checked, :selected, :disabled].each do |option|
            next unless @options[option]


            accept = if @options[option].respond_to?(:call)
                       @options[option].call(item)
                     else
                       Array(@options[option]).include?(value)
                     end

            if accept
              html_options[option] = true
            elsif option == :checked
              html_options[option] = false
            end
          end

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

            yield value, text, default_html_options
          end.join.html_safe
        end

        def value_for_collection(item, value) #:nodoc:
          value.respond_to?(:call) ? value.call(item) : item.send(value)
        end
      end
    end
  end
end
