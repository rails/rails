module ActionView
  module Helpers
    module Tags
      class CollectionCheckBoxes < CollectionRadioButtons
        delegate :check_box, :label, :to => :@template_object

        def render
          rendered_collection = render_collection do |value, text, default_html_options|
            default_html_options[:multiple] = true

            if block_given?
              yield sanitize_attribute_name(value), text, value, default_html_options
            else
              check_box(@object_name, @method_name, default_html_options, value, nil) +
                label(@object_name, sanitize_attribute_name(value), text, :class => "collection_check_boxes")
            end
          end

          # Append a hidden field to make sure something will be sent back to the
          # server if all check boxes are unchecked.
          hidden = @template_object.hidden_field_tag(tag_name_multiple, "", :id => nil)

          rendered_collection + hidden
        end
      end
    end
  end
end
