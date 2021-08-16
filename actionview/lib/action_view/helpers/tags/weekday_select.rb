# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class WeekdaySelect < Base # :nodoc:
        def initialize(object_name, method_name, template_object, options, html_options)
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          select_content_tag(
            weekday_options_for_select(
              value || @options[:selected],
              index_as_value: @options.fetch(:index_as_value, false),
              day_format: @options.fetch(:day_format, :day_names)
            ),
            @options,
            @html_options
          )
        end
      end
    end
  end
end
