require "action_view/helpers/tags/collection_helpers"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CollectionRadioButtons < Base # :nodoc:
        include CollectionHelpers

        class RadioButtonBuilder < Builder # :nodoc:
          def radio_button(extra_html_options = {})
            html_options = extra_html_options.merge(@input_html_options)
            html_options[:skip_default_ids] = false
            @template_object.radio_button(@object_name, @method_name, @value, html_options)
          end
        end

        def render(&block)
          render_collection_for(RadioButtonBuilder, &block)
        end

        private

          def render_component(builder)
            builder.radio_button + builder.label
          end
      end
    end
  end
end
