module ActionView
  module Helpers
    module Tags
      class TextArea < Base #:nodoc:
        DEFAULT_TEXT_AREA_OPTIONS = { "cols" => 40, "rows" => 20 }

        def render
          options = DEFAULT_TEXT_AREA_OPTIONS.merge(@options.stringify_keys)
          add_default_name_and_id(options)

          if size = options.delete("size")
            options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
          end

          content_tag("textarea", ERB::Util.html_escape(options.delete('value') || value_before_type_cast(object)), options)
        end
      end
    end
  end
end
