# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class GroupedCollectionSelect < Base # :nodoc:
        include SelectRenderer
        include FormOptionsHelper

        def initialize(object_name, method_name, template_object, collection, group_method, group_label_method, option_key_method, option_value_method, options, html_options)
          @collection          = collection
          @group_method        = group_method
          @group_label_method  = group_label_method
          @option_key_method   = option_key_method
          @option_value_method = option_value_method
          @html_options        = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          option_tags_options = {
            selected: @options.fetch(:selected) { value },
            disabled: @options[:disabled]
          }

          select_content_tag(
            option_groups_from_collection_for_select(@collection, @group_method, @group_label_method, @option_key_method, @option_value_method, option_tags_options), @options, @html_options
          )
        end
      end
    end
  end
end
