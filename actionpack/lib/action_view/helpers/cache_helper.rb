module ActionView
  module Helpers
    # See ActionController::Caching::Fragments for usage instructions.
    module CacheHelper
      def cache(name = {}, &block)
        @controller.cache_erb_fragment(block, name)
      end
    end
  end
end
