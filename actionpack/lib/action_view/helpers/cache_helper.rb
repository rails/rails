module ActionView
  module Helpers
    module CacheHelper
      def cache(binding, name, key = nil)
        @controller.cache_fragment(binding, name, key) { yield }
      end
    end
  end
end
