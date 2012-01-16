module ActionView
  module Helpers
    module Tags
      class TextField < Base #:nodoc:
        def render
          options = @options.stringify_keys
          options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
          options = DEFAULT_FIELD_OPTIONS.merge(options)
          options["type"]  ||= "text"
          options["value"] = options.fetch("value"){ value_before_type_cast(object) }
          options["value"] &&= ERB::Util.html_escape(options["value"])
          add_default_name_and_id(options)
          tag("input", options)
        end
      end
    end
  end
end
