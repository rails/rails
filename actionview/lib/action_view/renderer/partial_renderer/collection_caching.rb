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
        @template_eligibility = {}
        build_collection_by_cache_keys_with_eager_loaded_templates

        return yield unless cache_collection? || @collection_by_cache_keys.empty?

        cached_partials = collection_cache.read_multi(*@collection_by_cache_keys.keys)

        captured_render_indexes = []
        collection_to_render    = []
        @collection_by_cache_keys.each_with_index do |(key, object), index|
          unless cached_partials.key?(key)
            captured_render_indexes << index
            collection_to_render << object
          end
        end.values

        @collection = collection_to_render
        rendered_partials = @collection.empty? ? [] : yield(captured_render_indexes)

        index = 0
        @collection_by_cache_keys.map do |cache_key, _|
          cached_partials.fetch(cache_key) do
            rendered_partials[index].tap { index += 1 }
          end
        end
      end

      def cache_collection?
        @options[:cache] != false
      end

      def callable_cache_key?
        @options[:cache].respond_to?(:call)
      end

      def eligible_template?(template, path, as = nil)
        return unless cache_collection?

        @template_eligibility.fetch(path) do
          @template_eligibility[path] = template.eligible_for_collection_caching?(as: as)
        end
      end

      def build_collection_by_cache_keys_with_eager_loaded_templates
        @collection_by_cache_keys = {}
        seed = callable_cache_key? ? @options[:cache] : ->(i) { i }

        if @template
          if eligible_template?(@template, @path, @options[:as])
            @collection.each do |item|
              @collection_by_cache_keys[expanded_cache_key(seed.call(item), @template)] = item
            end
          end
        else
          @templates = {}
          keys = @locals.keys

          @collection.each_with_index do |item, index|
            path, as, counter, _ = @collection_data[index]

            @templates[path] ||= find_template(path, keys + [ as, counter ])
            template = @templates[path]

            @collection_by_cache_keys[expanded_cache_key(seed.call(item), template)] = item
          end
        end
      end

      def expanded_cache_key(key, template)
        key = @view.fragment_cache_key(@view.cache_fragment_name(key, virtual_path: template.virtual_path))
        key.frozen? ? key.dup : key # #read_multi & #write may require mutability, Dalli 2.6.0.
      end

      def collection_cache_rendered_partial(template, key_by, rendered_partial)
        if callable_cache_key?
          key = expanded_cache_key(@options[:cache].call(key_by), template)
          collection_cache.write(key, rendered_partial, @options[:cache_options])
        end
      end
  end
end
