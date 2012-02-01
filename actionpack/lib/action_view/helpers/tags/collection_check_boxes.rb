module ActionView
  module Helpers
    module Tags
      class CollectionCheckBoxes < CollectionRadioButtons
        def render
          rendered_collection = render_collection do |value, text, default_html_options|
            default_html_options[:multiple] = true

            if block_given?
              yield sanitize_attribute_name(value), text, value, default_html_options
            else
              check_box(value, default_html_options) +
                label(value, text, "collection_check_boxes")
            end
          end

          # Append a hidden field to make sure something will be sent back to the
          # server if all check boxes are unchecked.
          hidden = @template_object.hidden_field_tag(tag_name_multiple, "", :id => nil)

          rendered_collection + hidden
        end

        private

        def check_box(value, html_options)
          @template_object.check_box(@object_name, @method_name, html_options, value, nil)
        end
      end
    end
  end
end
