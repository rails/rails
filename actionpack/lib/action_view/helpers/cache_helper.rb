module ActionView
  # = Action View Cache Helper
  module Helpers
    module CacheHelper
      # This helper exposes a method for caching fragments of a view 
      # rather than an entire action or page. This technique is useful
      # caching pieces like menus, lists of newstopics, static HTML
      # fragments, and so on. This method takes a block that contains
      # the content you wish to cache. 
      #
      # The best way to use this is by doing key-based cache expiration
      # on top of a cache store like Memcached that'll automatically
      # kick out old entries. For more on key-based expiration, see:
      # http://37signals.com/svn/posts/3113-how-key-based-cache-expiration-works
      #
      # When using this method, you list the cache dependencies as part of
      # the name of the cache, like so:
      #
      #   <% cache [ "v1", project ] do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      #
      # This approach will assume that when a new topic is added, you'll touch
      # the project. The cache key generated from this call will be something like:
      #
      #   views/v1/projects/123-20120806214154
      #            ^class   ^id ^updated_at
      #
      # If you update the rendering of topics, you just bump the version to v2.
      # Otherwise the cache is automatically bumped whenever the project updated_at
      # is touched.
      def cache(name = {}, options = nil, &block)
        if controller.perform_caching
          safe_concat(fragment_for(name, options, &block))
        else
          yield
        end

        nil
      end

    private
      # TODO: Create an object that has caching read/write on it
      def fragment_for(name = {}, options = nil, &block) #:nodoc:
        if fragment = controller.read_fragment(name, options)
          fragment
        else
          # VIEW TODO: Make #capture usable outside of ERB
          # This dance is needed because Builder can't use capture
          pos = output_buffer.length
          yield
          output_safe = output_buffer.html_safe?
          fragment = output_buffer.slice!(pos..-1)
          if output_safe
            self.output_buffer = output_buffer.class.new(output_buffer)
          end
          controller.write_fragment(name, fragment, options)
        end
      end
    end
  end
end
