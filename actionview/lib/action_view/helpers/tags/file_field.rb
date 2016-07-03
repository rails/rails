module ActionView
  module Helpers
    module Tags # :nodoc:
      class FileField < TextField # :nodoc:
        def render
          options = @options.stringify_keys

          if accept = options["accept"]
            options["accept"] = Mime[accept] || accept
            @options = options
          end

          super
        end
      end
    end
  end
end
