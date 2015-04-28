module ActionView
  # = Action View Cache Helper
  module Helpers
    module CacheHelper
      # This helper exposes a method for caching fragments of a view
      # rather than an entire action or page. This technique is useful
      # caching pieces like menus, lists of new topics, static HTML
      # fragments, and so on. This method takes a block that contains
      # the content you wish to cache.
      #
      # The best way to use this is by doing key-based cache expiration
      # on top of a cache store like Memcached that'll automatically
      # kick out old entries. For more on key-based expiration, see:
      # http://signalvnoise.com/posts/3113-how-key-based-cache-expiration-works
      #
      # When using this method, you list the cache dependency as the name of the cache, like so:
      #
      #   <% cache project do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      #
      # This approach will assume that when a new topic is added, you'll touch
      # the project. The cache key generated from this call will be something like:
      #
      #   views/projects/123-20120806214154/7a1156131a6928cb0026877f8b749ac9
      #         ^class   ^id ^updated_at    ^template tree digest
      #
      # The cache is thus automatically bumped whenever the project updated_at is touched.
      #
      # If your template cache depends on multiple sources (try to avoid this to keep things simple),
      # you can name all these dependencies as part of an array:
      #
      #   <% cache [ project, current_user ] do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      #
      # This will include both records as part of the cache key and updating either of them will
      # expire the cache.
      #
      # ==== Template digest
      #
      # The template digest that's added to the cache key is computed by taking an md5 of the
      # contents of the entire template file. This ensures that your caches will automatically
      # expire when you change the template file.
      #
      # Note that the md5 is taken of the entire template file, not just what's within the
      # cache do/end call. So it's possible that changing something outside of that call will
      # still expire the cache.
      #
      # Additionally, the digestor will automatically look through your template file for
      # explicit and implicit dependencies, and include those as part of the digest.
      #
      # The digestor can be bypassed by passing skip_digest: true as an option to the cache call:
      #
      #   <% cache project, skip_digest: true do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      #
      # ==== Implicit dependencies
      #
      # Most template dependencies can be derived from calls to render in the template itself.
      # Here are some examples of render calls that Cache Digests knows how to decode:
      #
      #   render partial: "comments/comment", collection: commentable.comments
      #   render "comments/comments"
      #   render 'comments/comments'
      #   render('comments/comments')
      #
      #   render "header" => render("comments/header")
      #
      #   render(@topic)         => render("topics/topic")
      #   render(topics)         => render("topics/topic")
      #   render(message.topics) => render("topics/topic")
      #
      # It's not possible to derive all render calls like that, though. Here are a few examples of things that can't be derived:
      #
      #   render group_of_attachments
      #   render @project.documents.where(published: true).order('created_at')
      #
      # You will have to rewrite those to the explicit form:
      #
      #   render partial: 'attachments/attachment', collection: group_of_attachments
      #   render partial: 'documents/document', collection: @project.documents.where(published: true).order('created_at')
      #
      # === Explicit dependencies
      #
      # Some times you'll have template dependencies that can't be derived at all. This is typically
      # the case when you have template rendering that happens in helpers. Here's an example:
      #
      #   <%= render_sortable_todolists @project.todolists %>
      #
      # You'll need to use a special comment format to call those out:
      #
      #   <%# Template Dependency: todolists/todolist %>
      #   <%= render_sortable_todolists @project.todolists %>
      #
      # The pattern used to match these is /# Template Dependency: ([^ ]+)/, so it's important that you type it out just so.
      # You can only declare one template dependency per line.
      #
      # === External dependencies
      #
      # If you use a helper method, for example, inside of a cached block and you then update that helper,
      # you'll have to bump the cache as well. It doesn't really matter how you do it, but the md5 of the template file
      # must change. One recommendation is to simply be explicit in a comment, like:
      #
      #   <%# Helper Dependency Updated: May 6, 2012 at 6pm %>
      #   <%= some_helper_method(person) %>
      #
      # Now all you'll have to do is change that timestamp when the helper method changes.
      def cache(name = {}, options = nil, &block)
        if controller.respond_to?(:perform_caching) && controller.perform_caching
          safe_concat(fragment_for(cache_fragment_name(name, options), options, &block))
        else
          yield
        end

        nil
      end

      # Cache fragments of a view if +condition+ is true
      #
      #   <% cache_if admin?, project do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      def cache_if(condition, name = {}, options = nil, &block)
        if condition
          cache(name, options, &block)
        else
          yield
        end

        nil
      end

      # Cache fragments of a view unless +condition+ is true
      #
      #   <% cache_unless admin?, project do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      def cache_unless(condition, name = {}, options = nil, &block)
        cache_if !condition, name, options, &block
      end

      # This helper returns the name of a cache key for a given fragment cache
      # call. By supplying skip_digest: true to cache, the digestion of cache
      # fragments can be manually bypassed. This is useful when cache fragments
      # cannot be manually expired unless you know the exact key which is the
      # case when using memcached.
      def cache_fragment_name(name = {}, options = nil)
        skip_digest = options && options[:skip_digest]

        if skip_digest
          name
        else
          fragment_name_with_digest(name)
        end
      end

    private

      def fragment_name_with_digest(name) #:nodoc:
        if @virtual_path
          names  = Array(name.is_a?(Hash) ? controller.url_for(name).split("://").last : name)
          digest = Digestor.digest name: @virtual_path, finder: lookup_context, dependencies: view_cache_dependencies

          [ *names, digest ]
        else
          name
        end
      end

      # TODO: Create an object that has caching read/write on it
      def fragment_for(name = {}, options = nil, &block) #:nodoc:
        read_fragment_for(name, options) || write_fragment_for(name, options, &block)
      end

      def read_fragment_for(name, options) #:nodoc:
        controller.read_fragment(name, options)
      end

      def write_fragment_for(name, options) #:nodoc:
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
