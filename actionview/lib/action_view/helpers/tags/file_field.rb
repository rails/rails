# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class FileField < TextField # :nodoc:
        def render
          include_hidden = @options.delete(:include_hidden)
          options = @options.stringify_keys
          add_default_name_and_field(options)

          if options["multiple"] && include_hidden
            hidden_field_for_multiple_file(options) + super
          else
            super
          end
        end

        private
          def hidden_field_for_multiple_file(options)
            tag("input", "name" => options["name"], "type" => "hidden", "value" => "", "autocomplete" => "off")
          end
      end
    end
  end
end
