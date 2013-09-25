require 'action_view/helpers/tags/collection_helpers'

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CollectionCheckBoxes < Base # :nodoc:
        include CollectionHelpers

        class CheckBoxBuilder < Builder # :nodoc:
          def check_box(extra_html_options={})
            html_options = extra_html_options.merge(@input_html_options)
            @template_object.check_box(@object_name, @method_name, html_options, @value, nil)
          end
        end

        def render(&block)
          rendered_collection = render_collection do |item, value, text, default_html_options|
            default_html_options[:multiple] = true
            builder = instantiate_builder(CheckBoxBuilder, item, value, text, default_html_options)

            if block_given?
              @template_object.capture(builder, &block)
            else
              render_component(builder)
            end
          end

          # Append a hidden field to make sure something will be sent back to the
          # server if all check boxes are unchecked.
          hidden_name = @html_options[:name] || "#{tag_name}[]"
          hidden = @template_object.hidden_field_tag(hidden_name, "", :id => nil)

          rendered_collection + hidden
        end

        private

        def render_component(builder)
          builder.check_box + builder.label
        end
      end
    end
  end
end
