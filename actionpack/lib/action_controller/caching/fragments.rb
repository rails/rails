module ActionController
  module Caching
    # Fragment caching is used for caching various blocks within
    # views without caching the entire action as a whole. This is
    # useful when certain elements of an action change frequently or
    # depend on complicated state while other parts rarely change or
    # can be shared amongst multiple parties. The caching is done using
    # the +cache+ helper available in the Action View. See
    # ActionView::Helpers::CacheHelper for more information.
    #
    # While it's strongly recommended that you use key-based cache
    # expiration (see links in CacheHelper for more information),
    # it is also possible to manually expire caches. For example:
    #
    #   expire_fragment('name_of_cache')
    module Fragments
      # Given a key (as described in +expire_fragment+), returns
      # a key suitable for use in reading, writing, or expiring a
      # cached fragment. All keys are prefixed with <tt>views/</tt> and uses
      # ActiveSupport::Cache.expand_cache_key for the expansion.
      def fragment_cache_key(key)
        ActiveSupport::Cache.expand_cache_key(key.is_a?(Hash) ? url_for(key).split("://").last : key, :views)
      end

      # Writes +content+ to the location signified by
      # +key+ (see +expire_fragment+ for acceptable formats).
      def write_fragment(key, content, options = nil)
        return content unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :write_fragment, key do
          content = content.to_str
          cache_store.write(key, content, options)
        end
        content
      end

      # Reads a cached fragment from the location signified by +key+
      # (see +expire_fragment+ for acceptable formats).
      def read_fragment(key, options = nil)
        return unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :read_fragment, key do
          result = cache_store.read(key, options)
          result.respond_to?(:html_safe) ? result.html_safe : result
        end
      end

      # Check if a cached fragment from the location signified by
      # +key+ exists (see +expire_fragment+ for acceptable formats).
      def fragment_exist?(key, options = nil)
        return unless cache_configured?
        key = fragment_cache_key(key)

        instrument_fragment_cache :exist_fragment?, key do
          cache_store.exist?(key, options)
        end
      end

      # Removes fragments from the cache.
      #
      # +key+ can take one of three forms:
      #
      # * String - This would normally take the form of a path, like
      #   <tt>pages/45/notes</tt>.
      # * Hash - Treated as an implicit call to +url_for+, like
      #   <tt>{ controller: 'pages', action: 'notes', id: 45}</tt>
      # * Regexp - Will remove any fragment that matches, so
      #   <tt>%r{pages/\d*/notes}</tt> might remove all notes. Make sure you
      #   don't use anchors in the regex (<tt>^</tt> or <tt>$</tt>) because
      #   the actual filename matched looks like
      #   <tt>./cache/filename/path.cache</tt>. Note: Regexp expiration is
      #   only supported on caches that can iterate over all keys (unlike
      #   memcached).
      #
      # +options+ is passed through to the cache store's +delete+
      # method (or <tt>delete_matched</tt>, for Regexp keys).
      def expire_fragment(key, options = nil)
        return unless cache_configured?
        key = fragment_cache_key(key) unless key.is_a?(Regexp)

        instrument_fragment_cache :expire_fragment, key do
          if key.is_a?(Regexp)
            cache_store.delete_matched(key, options)
          else
            cache_store.delete(key, options)
          end
        end
      end

      def instrument_fragment_cache(name, key) # :nodoc:
        ActiveSupport::Notifications.instrument("#{name}.action_controller", :key => key){ yield }
      end
    end
  end
end
