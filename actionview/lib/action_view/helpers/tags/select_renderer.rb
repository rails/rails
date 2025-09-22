# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      module SelectRenderer # :nodoc:
        private
          def select_content_tag(option_tags, options, html_options)
            html_options = html_options.stringify_keys
            [:required, :multiple, :size].each do |prop|
              html_options[prop.to_s] = options.delete(prop) if options.key?(prop) && !html_options.key?(prop.to_s)
            end

            add_default_name_and_field(html_options)

            if placeholder_required?(html_options)
              raise ArgumentError, "include_blank cannot be false for a required field." if options[:include_blank] == false
              options[:include_blank] ||= true unless options[:prompt]
            end

            value = options.fetch(:selected) { value() }
            select = content_tag("select", add_options(option_tags, options, value), html_options)

            if html_options["multiple"] && options.fetch(:include_hidden, true)
              tag("input", disabled: html_options["disabled"], name: html_options["name"], type: "hidden", value: "", autocomplete: "off") + select
            else
              select
            end
          end

          def placeholder_required?(html_options)
            # See https://html.spec.whatwg.org/multipage/forms.html#attr-select-required
            html_options["required"] && !html_options["multiple"] && html_options.fetch("size", 1).to_i == 1
          end

          def add_options(option_tags, options, value = nil)
            if options[:include_blank]
              content = (options[:include_blank] if options[:include_blank].is_a?(String))
              label = (" " unless content)
              option_tags = tag_builder.content_tag_string("option", content, value: "", label: label) + "\n" + option_tags
            end

            if value.blank? && options[:prompt]
              tag_options = { value: "" }.tap do |prompt_opts|
                prompt_opts[:disabled] = true if options[:disabled] == ""
                prompt_opts[:selected] = true if options[:selected] == ""
              end
              option_tags = tag_builder.content_tag_string("option", prompt_text(options[:prompt]), tag_options) + "\n" + option_tags
            end

            option_tags
          end
      end
    end
  end
end
