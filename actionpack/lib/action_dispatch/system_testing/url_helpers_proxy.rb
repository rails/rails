# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    module UrlHelpersProxy # :nodoc:
      private
        def method_missing(name, ...)
          if url_helpers.respond_to?(name)
            url_helpers.public_send(name, ...)
          else
            super
          end
        end

        def respond_to_missing?(name, include_private = false)
          url_helpers.respond_to?(name) || super
        end
    end
  end
end
