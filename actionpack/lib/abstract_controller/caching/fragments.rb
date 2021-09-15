# frozen_string_literal: true

module AbstractController
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
      extend ActiveSupport::Concern

      included do
        if respond_to?(:class_attribute)
          class_attribute :fragment_cache_keys
        else
          mattr_writer :fragment_cache_keys
        end

        self.fragment_cache_keys = []

        if respond_to?(:helper_method)
          helper_method :combined_fragment_cache_key
        end
      end

      module ClassMethods
        # Allows you to specify controller-wide key prefixes for
        # cache fragments. Pass either a constant +value+, or a block
        # which computes a value each time a cache key is generated.
        #
        # For example, you may want to prefix all fragment cache keys
        # with a global version identifier, so you can easily
        # invalidate all caches.
        #
        #   class ApplicationController
        #     fragment_cache_key "v1"
        #   end
        #
        # When it's time to invalidate all fragments, simply change
        # the string constant. Or, progressively roll out the cache
        # invalidation using a computed value:
        #
        #   class ApplicationController
        #     fragment_cache_key do
        #       @account.id.odd? ? "v1" : "v2"
        #     end
        #   end
        def fragment_cache_key(value = nil, &key)
          self.fragment_cache_keys += [key || -> { value }]
        end
      end

      # Given a key (as described in +expire_fragment+), returns
      # a key array suitable for use in reading, writing, or expiring a
      # cached fragment. All keys begin with <tt>:views</tt>,
      # followed by <tt>ENV["RAILS_CACHE_ID"]</tt> or <tt>ENV["RAILS_APP_VERSION"]</tt> if set,
      # followed by any controller-wide key prefix values, ending
      # with the specified +key+ value.
      def combined_fragment_cache_key(key)
        head = self.class.fragment_cache_keys.map { |k| instance_exec(&k) }
        tail = key.is_a?(Hash) ? url_for(key).split("://").last : key

        cache_key = [:views, ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"], head, tail]
        cache_key.flatten!(1)
        cache_key.compact!
        cache_key
      end

      # Writes +content+ to the location signified by
      # +key+ (see +expire_fragment+ for acceptable formats).
      def write_fragment(key, content, options = nil)
        return content unless cache_configured?

        key = combined_fragment_cache_key(key)
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

        key = combined_fragment_cache_key(key)
        instrument_fragment_cache :read_fragment, key do
          result = cache_store.read(key, options)
          result.respond_to?(:html_safe) ? result.html_safe : result
        end
      end

      # Check if a cached fragment from the location signified by
      # +key+ exists (see +expire_fragment+ for acceptable formats).
      def fragment_exist?(key, options = nil)
        return unless cache_configured?
        key = combined_fragment_cache_key(key)

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
        key = combined_fragment_cache_key(key) unless key.is_a?(Regexp)

        instrument_fragment_cache :expire_fragment, key do
          if key.is_a?(Regexp)
            cache_store.delete_matched(key, options)
          else
            cache_store.delete(key, options)
          end
        end
      end

      def instrument_fragment_cache(name, key, &block) # :nodoc:
        ActiveSupport::Notifications.instrument("#{name}.#{instrument_name}", instrument_payload(key), &block)
      end
    end
  end
end
