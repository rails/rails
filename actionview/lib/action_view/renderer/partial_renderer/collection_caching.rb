# frozen_string_literal: true

module ActionView
  module CollectionCaching # :nodoc:
    extend ActiveSupport::Concern

    included do
      # Fallback cache store if Action View is used without Rails.
      # Otherwise overridden in Railtie to use Rails.cache.
      mattr_accessor :collection_cache, default: ActiveSupport::Cache::MemoryStore.new
    end

    private
      def cache_collection_render(instrumentation_payload, view, template)
        return yield unless @options[:cached] && view.controller.respond_to?(:perform_caching) && view.controller.perform_caching

        # Result is a hash with the key represents the
        # key used for cache lookup and the value is the item
        # on which the partial is being rendered
        keyed_collection, ordered_keys = collection_by_cache_keys(view, template)

        # Pull all partials from cache
        # Result is a hash, key matches the entry in
        # `keyed_collection` where the cache was retrieved and the
        # value is the value that was present in the cache
        cached_partials = collection_cache.read_multi(*keyed_collection.keys)
        instrumentation_payload[:cache_hits] = cached_partials.size

        # Extract the items for the keys that are not found
        # Set the uncached values to instance variable @collection
        # which is used by the caller
        @collection = keyed_collection.reject { |key, _| cached_partials.key?(key) }.values

        # If all elements are already in cache then
        # rendered partials will be an empty array
        #
        # If the cache is missing elements then
        # the block will be called against the remaining items
        # in the @collection.
        rendered_partials = @collection.empty? ? [] : yield

        index = 0
        keyed_partials = fetch_or_cache_partial(cached_partials, template, order_by: keyed_collection.each_key) do
          # This block is called once
          # for every cache miss while preserving order.
          rendered_partials[index].tap { index += 1 }
        end

        ordered_keys.map do |key|
          keyed_partials[key]
        end
      end

      def callable_cache_key?
        @options[:cached].respond_to?(:call)
      end

      def collection_by_cache_keys(view, template)
        seed = callable_cache_key? ? @options[:cached] : ->(i) { i }

        digest_path = view.digest_path_from_template(template)

        @collection.each_with_object([{}, []]) do |item, (hash, ordered_keys)|
          key = expanded_cache_key(seed.call(item), view, template, digest_path)
          ordered_keys << key
          hash[key] = item
        end
      end

      def expanded_cache_key(key, view, template, digest_path)
        key = view.combined_fragment_cache_key(view.cache_fragment_name(key, virtual_path: template.virtual_path, digest_path: digest_path))
        key.frozen? ? key.dup : key # #read_multi & #write may require mutability, Dalli 2.6.0.
      end

      # `order_by` is an enumerable object containing keys of the cache,
      # all keys are  passed in whether found already or not.
      #
      # `cached_partials` is a hash. If the value exists
      # it represents the rendered partial from the cache
      # otherwise `Hash#fetch` will take the value of its block.
      #
      # This method expects a block that will return the rendered
      # partial. An example is to render all results
      # for each element that was not found in the cache and store it as an array.
      # Order it so that the first empty cache element in `cached_partials`
      # corresponds to the first element in `rendered_partials`.
      #
      # If the partial is not already cached it will also be
      # written back to the underlying cache store.
      def fetch_or_cache_partial(cached_partials, template, order_by:)
        order_by.each_with_object({}) do |cache_key, hash|
            hash[cache_key] =
              if content = cached_partials[cache_key]
                build_rendered_template(content, template)
              else
                yield.tap do |rendered_partial|
                  collection_cache.write(cache_key, rendered_partial.body)
                end
              end
          end
      end
  end
end
