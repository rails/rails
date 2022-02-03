# frozen_string_literal: true

require "action_view/helpers/tags/select_renderer"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CollectionSelect < Base # :nodoc:
        include SelectRenderer

        def initialize(object_name, method_name, template_object, collection, value_method, text_method, options, html_options)
          @collection   = collection
          @value_method = value_method
          @text_method  = text_method
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        private
          def option_tags
            options_from_collection_for_select(@collection, @value_method, @text_method, option_tags_options)
          end
      end
    end
  end
end
