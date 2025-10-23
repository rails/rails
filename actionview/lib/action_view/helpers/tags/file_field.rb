# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class FileField < TextField # :nodoc:
        def to_s
          include_hidden = @options.fetch(:include_hidden)
          options = attributes

          if options["multiple"] && include_hidden
            hidden_field_for_multiple_file(options) + super
          else
            super
          end
        end

        def attributes
          @options.delete(:include_hidden)
          options = @options.stringify_keys
          add_default_name_and_field(options)
          super
        end

        private
          def hidden_field_for_multiple_file(options)
            tag_options = { "name" => options["name"], "type" => "hidden", "value" => "" }
            tag_options["autocomplete"] = "off" unless ActionView::Base.remove_hidden_field_autocomplete
            tag("input", tag_options)
          end
      end
    end
  end
end
