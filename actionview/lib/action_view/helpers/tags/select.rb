# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class Select < Base # :nodoc:
        include SelectRenderer
        include FormOptionsHelper

        def initialize(object_name, method_name, template_object, choices, options, html_options)
          @choices = block_given? ? template_object.capture { yield || "" } : choices
          @choices = @choices.to_a if @choices.is_a?(Range)

          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          option_tags_options = {
            selected: @options.fetch(:selected) { value.nil? ? "" : value },
            disabled: @options[:disabled]
          }

          option_tags = if grouped_choices?
            grouped_options_for_select(@choices, option_tags_options)
          else
            options_for_select(@choices, option_tags_options)
          end

          select_content_tag(option_tags, @options, @html_options)
        end

        private
          # Grouped choices look like this:
          #
          #   [nil, []]
          #   { nil => [] }
          def grouped_choices?
            return false if @choices.blank?

            first_choice = @choices.first
            return false unless first_choice.is_a?(Enumerable)

            first_choice.second.is_a?(Array)
          end
      end
    end
  end
end
