module ActionView
  module Helpers
    # See ActionController::Caching::Fragments for usage instructions.
    module CacheHelper
      def cache(binding, name, key = nil)
        @controller.cache_erb_fragment(binding, name, key) { yield }
      end
    end
  end
end
