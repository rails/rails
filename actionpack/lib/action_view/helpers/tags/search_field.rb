module ActionView
  module Helpers
    module Tags # :nodoc:
      class SearchField < TextField # :nodoc:
        def render
          super do |options|
            if options["autosave"]
              if options["autosave"] == true
                options["autosave"] = request.host.split(".").reverse.join(".")
              end
              options["results"] ||= 10
            end

            if options["onsearch"]
              options["incremental"] = true unless options.has_key?("incremental")
            end
          end
        end
      end
    end
  end
end
