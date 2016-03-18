module ActionView
  module CollectionCaching # :nodoc:
    extend ActiveSupport::Concern

    included do
      # Fallback cache store if Action View is used without Rails.
      # Otherwise overridden in Railtie to use Rails.cache.
      mattr_accessor(:collection_cache) { ActiveSupport::Cache::MemoryStore.new }
    end

    private
      def cache_collection_render(instrumentation_payload)
        return yield unless @options[:cached]

        keyed_collection = collection_by_cache_keys
        cached_partials  = collection_cache.read_multi(*keyed_collection.keys)
        instrumentation_payload[:cache_hits] = cached_partials.size

        @collection = keyed_collection.reject { |key, _| cached_partials.key?(key) }.values
        rendered_partials = @collection.empty? ? [] : yield

        index = 0
        fetch_or_cache_partial(cached_partials, order_by: keyed_collection.each_key) do
          rendered_partials[index].tap { index += 1 }
        end
      end

      def collection_by_cache_keys
        @collection.each_with_object({}) do |item, hash|
          hash[expanded_cache_key(item)] = item
        end
      end

      def expanded_cache_key(key)
        key = @view.fragment_cache_key(@view.cache_fragment_name(key, virtual_path: @template.virtual_path))
        key.frozen? ? key.dup : key # #read_multi & #write may require mutability, Dalli 2.6.0.
      end

      def fetch_or_cache_partial(cached_partials, order_by:)
        order_by.map do |cache_key|
          cached_partials.fetch(cache_key) do
            yield.tap do |rendered_partial|
              collection_cache.write(cache_key, rendered_partial)
            end
          end
        end
      end
  end
end
