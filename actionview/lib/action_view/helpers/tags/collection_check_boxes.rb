require "action_view/helpers/tags/collection_helpers"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CollectionCheckBoxes < Base # :nodoc:
        include CollectionHelpers

        class CheckBoxBuilder < Builder # :nodoc:
          def check_box(extra_html_options = {})
            html_options = extra_html_options.merge(@input_html_options)
            html_options[:multiple] = true
            html_options[:skip_default_ids] = false
            @template_object.check_box(@object_name, @method_name, html_options, @value, nil)
          end
        end

        def render(&block)
          render_collection_for(CheckBoxBuilder, &block)
        end

        private

          def render_component(builder)
            builder.check_box + builder.label
          end

          def hidden_field_name
            "#{super}[]"
          end
      end
    end
  end
end
