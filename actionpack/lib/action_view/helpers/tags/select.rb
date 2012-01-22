module ActionView
  module Helpers
    module Tags
      class Select < Base #:nodoc:
        def initialize(object_name, method_name, template_object, choices, options, html_options)
          @choices = choices
          @choices = @choices.to_a if @choices.is_a?(Range)
          @html_options = html_options

          super(object_name, method_name, template_object, options)
        end

        def render
          selected_value = @options.has_key?(:selected) ? @options[:selected] : value(@object)

          # Grouped choices look like this:
          #
          #   [nil, []]
          #   { nil => [] }
          #
          if !@choices.empty? && @choices.first.respond_to?(:last) && Array === @choices.first.last
            option_tags = grouped_options_for_select(@choices, :selected => selected_value, :disabled => @options[:disabled])
          else
            option_tags = options_for_select(@choices, :selected => selected_value, :disabled => @options[:disabled])
          end

          select_content_tag(option_tags, @options, @html_options)
        end
      end
    end
  end
end
