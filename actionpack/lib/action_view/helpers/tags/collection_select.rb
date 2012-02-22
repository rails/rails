module ActionView
  module Helpers
    module Tags
      class CollectionSelect < Base #:nodoc:
        def initialize(object_name, method_name, template_object, collection, value_method, text_method, options, html_options)
          @collection   = collection
          @value_method = value_method
          @text_method  = text_method
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          option_tags_options = {
            :selected => @options.fetch(:selected) { value(@object) },
            :disabled => @options[:disabled]
          }

          select_content_tag(
            options_from_collection_for_select(@collection, @value_method, @text_method, option_tags_options),
            @options, @html_options
          )
        end
      end
    end
  end
end
