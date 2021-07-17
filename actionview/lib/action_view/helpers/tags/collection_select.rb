# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActionView
  module Helpers
    module Tags # :nodoc:
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
            selected: @options.fetch(:selected) { value },
            disabled: @options[:disabled]
          }

          option_tags = if grouped_collection?
            option_groups_from_collection_for_select(@collection, :last, :first, @value_method, @text_method, option_tags_options)
          else
            options_from_collection_for_select(@collection, @value_method, @text_method, option_tags_options)
          end

          select_content_tag(option_tags, @options, @html_options)
        end

        private
          def grouped_collection?
            case @collection
            when Hash, Array
              @collection.first&.try(:last).is_a?(Array)
            end
          end
      end
    end
  end
end
