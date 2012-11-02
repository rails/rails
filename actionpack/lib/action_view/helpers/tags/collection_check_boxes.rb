require 'action_view/helpers/tags/collection_helpers'

module ActionView
  module Helpers
    module Tags
      class CollectionCheckBoxes < Base
        include CollectionHelpers

        class CheckBoxBuilder < Builder
          def check_box(extra_html_options={})
            html_options = extra_html_options.merge(@input_html_options)
            @template_object.check_box(@object_name, @method_name, html_options, @value, nil)
          end
        end

        def render
          rendered_collection = render_collection do |item, value, text, default_html_options|
            default_html_options[:multiple] = true
            builder = instantiate_builder(CheckBoxBuilder, item, value, text, default_html_options)

            if block_given?
              yield builder
            else
              builder.check_box + builder.label
            end
          end

          # Append a hidden field to make sure something will be sent back to the
          # server if all check boxes are unchecked.
          hidden = @template_object.hidden_field_tag("#{tag_name}[]", "", :id => nil)

          rendered_collection + hidden
        end
      end
    end
  end
end
