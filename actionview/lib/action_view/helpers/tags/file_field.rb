module ActionView
  module Helpers
    module Tags # :nodoc:
      class FileField < TextField # :nodoc:

        def render
          options = @options.stringify_keys

          if options.fetch("include_hidden", true)
            add_default_name_and_id(options)
            options[:type] = "file"
            tag("input", name: options["name"], type: "hidden", value: "") + tag("input", options)
          else
            options.delete("include_hidden")
            @options = options

            super
          end
        end
      end
    end
  end
end
