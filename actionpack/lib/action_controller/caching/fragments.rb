module ActionController #:nodoc:
  module Caching
    # Fragment caching is used for caching various blocks within 
    # views without caching the entire action as a whole. This is
    # useful when certain elements of an action change frequently or 
    # depend on complicated state while other parts rarely change or 
    # can be shared amongst multiple parties. The caching is done using
    # the <tt>cache</tt> helper available in the Action View. A 
    # template with fragment caching might look like:
    #
    #   <b>Hello <%= @name %></b>
    #
    #   <% cache do %>
    #     All the topics in the system:
    #     <%= render :partial => "topic", :collection => Topic.all %>
    #   <% end %>
    #
    # This cache will bind the name of the action that called it, so if
    # this code was part of the view for the topics/list action, you 
    # would be able to invalidate it using:
    #
    #   expire_fragment(:controller => "topics", :action => "list")
    #
    # This default behavior is limited if you need to cache multiple 
    # fragments per action or if the action itself is cached using 
    # <tt>caches_action</tt>. To remedy this, there is an option to 
    # qualify the name of the cached fragment by using the 
    # <tt>:action_suffix</tt> option:
    #
    #   <% cache(:action => "list", :action_suffix => "all_topics") do %>
    #
    # That would result in a name such as 
    # <tt>/topics/list/all_topics</tt>, avoiding conflicts with the 
    # action cache and with any fragments that use a different suffix.
    # Note that the URL doesn't have to really exist or be callable
    # - the url_for system is just used to generate unique cache names
    # that we can refer to when we need to expire the cache.
    #
    # The expiration call for this example is:
    #
    #   expire_fragment(:controller => "topics", 
    #                   :action => "list", 
    #                   :action_suffix => "all_topics")
    module Fragments
      # Given a key (as described in <tt>expire_fragment</tt>), returns
      # a key suitable for use in reading, writing, or expiring a 
      # cached fragment. If the key is a hash, the generated key is the
      # return value of url_for on that hash (without the protocol). 
      # All keys are prefixed with <tt>views/</tt> and uses
      # ActiveSupport::Cache.expand_cache_key for the expansion.
      def fragment_cache_key(key)
        ActiveSupport::Cache.expand_cache_key(key.is_a?(Hash) ? url_for(key).split("://").last : key, :views)
      end

      # Writes <tt>content</tt> to the location signified by 
      # <tt>key</tt> (see <tt>expire_fragment</tt> for acceptable formats).
      def write_fragment(key, content, options = nil)
        return content unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :write_fragment, key do
          content = content.to_str
          cache_store.write(key, content, options)
        end
        content
      end

      # Reads a cached fragment from the location signified by <tt>key</tt>
      # (see <tt>expire_fragment</tt> for acceptable formats).
      def read_fragment(key, options = nil)
        return unless cache_configured?

        key = fragment_cache_key(key)
        instrument_fragment_cache :read_fragment, key do
          result = cache_store.read(key, options)
          result.respond_to?(:html_safe) ? result.html_safe : result
        end
      end

      # Check if a cached fragment from the location signified by 
      # <tt>key</tt> exists (see <tt>expire_fragment</tt> for acceptable formats)
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
      #   <tt>{:controller => "pages", :action => "notes", :id => 45}</tt>
      # * Regexp - Will remove any fragment that matches, so
      #   <tt>%r{pages/\d*/notes}</tt> might remove all notes. Make sure you
      #   don't use anchors in the regex (<tt>^</tt> or <tt>$</tt>) because
      #   the actual filename matched looks like
      #   <tt>./cache/filename/path.cache</tt>. Note: Regexp expiration is
      #   only supported on caches that can iterate over all keys (unlike
      #   memcached).
      #
      # +options+ is passed through to the cache store's <tt>delete</tt>
      # method (or <tt>delete_matched</tt>, for Regexp keys.)
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

      def instrument_fragment_cache(name, key)
        ActiveSupport::Notifications.instrument("#{name}.action_controller", :key => key){ yield }
      end
    end
  end
end
