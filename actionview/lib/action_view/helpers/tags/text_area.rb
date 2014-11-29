require 'action_view/helpers/tags/placeholderable'

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TextArea < Base # :nodoc:
        include Placeholderable

        def render
          options = @options.stringify_keys
          add_default_name_and_id(options)

          if size = options.delete("size")
            options["cols"], options["rows"] = size.try(:split, "x")
          end

          content_tag("textarea", options.delete("value") { value_before_type_cast(object) }, options)
        end
      end
    end
  end
end
