# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class CollectionSelect < Base # :nodoc:
        def initialize(object_name, method_name, template_object, collection, value_method, text_method, options, html_options)
          @collection   = collection
          @value_method = value_method
          @text_method  = text_method
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          select_content_tag(option_tags, @options, @html_options)
        end

        private
          def collection_grouped?
            entry = @collection.first if @collection.is_a?(Hash) || @collection.is_a?(Array)
            entry.respond_to?(:last) && entry.last.is_a?(Array)
          end

          def option_tags
            html_options = { selected: @options.fetch(:selected) { value }, disabled: @options[:disabled] }

            if collection_grouped?
              option_groups_from_collection_for_select(@collection, :last, :first, @value_method, @text_method, html_options)
            else
              options_from_collection_for_select(@collection, @value_method, @text_method, html_options)
            end
          end
      end
    end
  end
end
