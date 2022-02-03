# frozen_string_literal: true

### require "action_view/helpers/tags/checkable"

module ActionView
  module Helpers
    module Tags # :nodoc:
      module SelectRenderer # :nodoc:
        def render
          select_content_tag(option_tags, @options, @html_options)
        end

        private
          def selected_value
            value = self.value
            value.nil? ? "" : value
          end

          def option_tags_options
            { selected: @options.fetch(:selected) { selected_value }, disabled: @options[:disabled] }
          end
      end
    end
  end
end
