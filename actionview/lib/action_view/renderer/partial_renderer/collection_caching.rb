require 'active_support/core_ext/object/try'

module ActionView
  module CollectionCaching # :nodoc:
    extend ActiveSupport::Concern

    included do
      # Fallback cache store if Action View is used without Rails.
      # Otherwise overridden in Railtie to use Rails.cache.
      mattr_accessor(:collection_cache) { ActiveSupport::Cache::MemoryStore.new }
    end

    private
      def cache_collection_render
        return yield unless cache_collection?

        keyed_collection = collection_by_cache_keys
        partial_cache = collection_cache.read_multi(*keyed_collection.keys)

        @collection = keyed_collection.reject { |key, _| partial_cache.key?(key) }.values
        rendered_partials = @collection.any? ? yield.dup : []

        fetch_or_cache_partial(partial_cache, order_by: keyed_collection.each_key) do
          rendered_partials.shift
        end
      end

      def cache_collection?
        @options.fetch(:cache, automatic_cache_eligible?)
      end

      def automatic_cache_eligible?
        @template && !callable_cache_key? &&
          @template.eligible_for_collection_caching?(as: @options[:as])
      end

      def callable_cache_key?
        @options[:cache].respond_to?(:call)
      end

      def collection_by_cache_keys
        seed = callable_cache_key? ? @options[:cache] : ->(i) { i }

        @collection.each_with_object({}) do |item, hash|
          hash[expanded_cache_key(seed.call(item))] = item
        end
      end

      def expanded_cache_key(key)
        key = @view.fragment_cache_key(@view.cache_fragment_name(key, virtual_path: @template.virtual_path))
        key.frozen? ? key.dup : key # #read_multi & #write may require mutability, Dalli 2.6.0.
      end

      def fetch_or_cache_partial(cached_partials, order_by:)
        order_by.map do |key|
          cached_partials.fetch(key) do
            yield.tap do |rendered_partial|
              collection_cache.write(key, rendered_partial, @options[:cache_options])
            end
          end
        end
      end
  end
end
