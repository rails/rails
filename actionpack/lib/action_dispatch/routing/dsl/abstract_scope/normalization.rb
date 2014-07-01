require 'action_dispatch/journey'

module ActionDispatch
  module Routing
    module DSL
      class AbstractScope
        protected
        # Invokes Journey::Router::Utils.normalize_path and ensure that
        # (:locale) becomes (/:locale) instead of /(:locale). Except
        # for root cases, where the latter is the correct one.
        def normalize_path(path)
          path = Journey::Router::Utils.normalize_path(path)
          path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^)]+\)$}
          path
        end

        def normalize_name(name)
          normalize_path(name)[1..-1].tr("/", "_")
        end
      end
    end
  end
end
