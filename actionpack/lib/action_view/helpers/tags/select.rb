module ActionView
  module Helpers
    module Tags
      class Select < Base #:nodoc:
        include FormOptionsHelper

        def initialize(object_name, method_name, template_object, choices, options, html_options)
          @choices = choices
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

        private

        def select_content_tag(option_tags, options, html_options)
          html_options = html_options.stringify_keys
          add_default_name_and_id(html_options)
          select = content_tag("select", add_options(option_tags, options, value(object)), html_options)
          if html_options["multiple"]
            tag("input", :disabled => html_options["disabled"], :name => html_options["name"], :type => "hidden", :value => "") + select
          else
            select
          end
        end

        def add_options(option_tags, options, value = nil)
          if options[:include_blank]
            option_tags = "<option value=\"\">#{ERB::Util.html_escape(options[:include_blank]) if options[:include_blank].kind_of?(String)}</option>\n" + option_tags
          end
          if value.blank? && options[:prompt]
            prompt = options[:prompt].kind_of?(String) ? options[:prompt] : I18n.translate('helpers.select.prompt', :default => 'Please select')
            option_tags = "<option value=\"\">#{ERB::Util.html_escape(prompt)}</option>\n" + option_tags
          end
          option_tags.html_safe
        end
      end
    end
  end
end
