# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActionView
  module CollectionCaching # :nodoc:
    extend ActiveSupport::Concern

    included do
      # Fallback cache store if Action View is used without Rails.
      # Otherwise overridden in Railtie to use Rails.cache.
      mattr_accessor :collection_cache, default: ActiveSupport::Cache::MemoryStore.new
    end

    private
      def will_cache?(options, view)
        options[:cached] && view.controller.respond_to?(:perform_caching) && view.controller.perform_caching
      end

      def cache_collection_render(instrumentation_payload, view, template, collection)
        return yield(collection) unless will_cache?(@options, view)

        collection_iterator = collection

        # Result is a hash with the key represents the
        # key used for cache lookup and the value is the item
        # on which the partial is being rendered
        keyed_collection, ordered_keys = collection_by_cache_keys(view, template, collection)

        # Pull all partials from cache
        # Result is a hash, key matches the entry in
        # `keyed_collection` where the cache was retrieved and the
        # value is the value that was present in the cache
        cached_partials = collection_cache.read_multi(*keyed_collection.keys)
        instrumentation_payload[:cache_hits] = cached_partials.size

        # Extract the items for the keys that are not found
        collection = keyed_collection.reject { |key, _| cached_partials.key?(key) }.values

        rendered_partials = collection.empty? ? [] : yield(collection_iterator.from_collection(collection))

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

      def callable_cache_key
        if @options[:cached].is_a?(Hash) && @options[:cached][:key].respond_to?(:call)
          @options[:cached][:key]
        elsif @options[:cached].respond_to?(:call)
          @options[:cached]
        end
      end

      def callable_cache_key?
        callable_cache_key.present?
      end

      def collection_by_cache_keys(view, template, collection)
        seed = callable_cache_key? ? callable_cache_key : ->(i) { i }

        digest_path = view.digest_path_from_template(template)
        collection.preload! if callable_cache_key?

        collection.each_with_object([{}, []]) do |item, (hash, ordered_keys)|
          key = expanded_cache_key(seed.call(item), view, template, digest_path)
          ordered_keys << key
          hash[key] = item
        end
      end

      def expanded_cache_key(key, view, template, digest_path)
        key = view.combined_fragment_cache_key(view.cache_fragment_name(key, digest_path: digest_path))
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
        entries_to_write = {}

        keyed_partials = order_by.index_with do |cache_key|
          if content = cached_partials[cache_key]
            build_rendered_template(content, template)
          else
            rendered_partial = yield
            body = rendered_partial.body

            # We want to cache buffers as raw strings. This both improve performance and
            # avoid creating forward compatibility issues with the internal representation
            # of these two types.
            if body.is_a?(ActionView::OutputBuffer) || body.is_a?(ActiveSupport::SafeBuffer)
              body = body.to_str
            end

            entries_to_write[cache_key] = body
            rendered_partial
          end
        end

        unless entries_to_write.empty?
          if @options[:cached].is_a?(Hash) && @options[:cached].key?(:expires_in)
            collection_cache.write_multi(entries_to_write, expires_in: @options[:cached][:expires_in])
          else
            collection_cache.write_multi(entries_to_write)
          end
        end

        keyed_partials
      end
  end
end
