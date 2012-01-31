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
  end
end
