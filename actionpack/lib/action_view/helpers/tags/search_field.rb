module ActionView
  module Helpers
    module Tags
      class SearchField < TextField #:nodoc:
        def render
          options = @options.stringify_keys

          if options["autosave"]
            if options["autosave"] == true
              options["autosave"] = request.host.split(".").reverse.join(".")
            end
            options["results"] ||= 10
          end

          if options["onsearch"]
            options["incremental"] = true unless options.has_key?("incremental")
          end

          super
        end
      end
    end
  end
end
