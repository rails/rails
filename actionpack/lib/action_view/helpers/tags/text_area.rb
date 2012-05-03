module ActionView
  module Helpers
    module Tags
      class TextArea < Base #:nodoc:
        def render
          options = @options.stringify_keys
          add_default_name_and_id(options)

          extract_size!(options, 'cols', 'rows')

          content_tag("textarea", options.delete('value') || value_before_type_cast(object), options)
        end
      end
    end
  end
end
