module ActionView
  module Helpers
    module FormCollectionsHelper
      def collection_radio_buttons(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionRadioButtons.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end

      def collection_check_boxes(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionCheckBoxes.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end
    end

    class FormBuilder
      def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_radio_buttons(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end

      def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_check_boxes(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end
    end
  end
end
