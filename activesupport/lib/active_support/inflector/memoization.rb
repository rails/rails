# -- THIS IS A QUICK HACK TO EVALUATE IF THIS IS WORTHWHILE. --------------

require 'lru_redux'

LruRedux::Cache.class_eval do
  def fetch(key)
    self[key] = yield unless @data.key?(key)
    self[key]
  end
end

module ActiveSupport
  module Inflector
    LRU_CACHE_SIZE = 200
    LRU_CACHES = []

    def self.clear_lru_caches
      LRU_CACHES.each(&:clear)
    end

    def self.memoize(method_name)
      cache = LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      LRU_CACHES << cache

      alias_method "#{method_name}_without_lru_cache", method_name

      # Note that so far no method in the inflector gets a block.
      define_method(method_name) do |*args|
        cache.fetch(args) do
          send("#{method_name}_without_lru_cache", *args)
        end
      end
    end
  end
end
