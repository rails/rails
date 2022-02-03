# frozen_string_literal: true

require "action_view/helpers/tags/select_renderer"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class Select < Base # :nodoc:
        include SelectRenderer

        def initialize(object_name, method_name, template_object, choices, options, html_options)
          @choices = block_given? ? template_object.capture { yield || "" } : choices
          @choices = @choices.to_a if @choices.is_a?(Range)

          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        private
          # Grouped choices look like this:
          #
          #   [nil, []]
          #   { nil => [] }
          def grouped_choices?
            !@choices.blank? && @choices.first.respond_to?(:last) && Array === @choices.first.last
          end

          def option_tags
            if grouped_choices?
              grouped_options_for_select(@choices, option_tags_options)
            else
              options_for_select(@choices, option_tags_options)
            end
          end
      end
    end
  end
end
