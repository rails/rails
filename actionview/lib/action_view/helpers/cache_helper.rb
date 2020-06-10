# frozen_string_literal: true

module ActionView
  # = Action View Cache Helper
  module Helpers #:nodoc:
    module CacheHelper
      # This helper exposes a method for caching fragments of a view
      # rather than an entire action or page. This technique is useful
      # caching pieces like menus, lists of new topics, static HTML
      # fragments, and so on. This method takes a block that contains
      # the content you wish to cache.
      #
      # The best way to use this is by doing recyclable key-based cache expiration
      # on top of a cache store like Memcached or Redis that'll automatically
      # kick out old entries.
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
      #   views/template/action:7a1156131a6928cb0026877f8b749ac9/projects/123
      #         ^template path  ^template tree digest            ^class   ^id
      #
      # This cache key is stable, but it's combined with a cache version derived from the project
      # record. When the project updated_at is touched, the #cache_version changes, even
      # if the key stays stable. This means that unlike a traditional key-based cache expiration
      # approach, you won't be generating cache trash, unused keys, simply because the dependent
      # record is updated.
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
      # ==== \Template digest
      #
      # The template digest that's added to the cache key is computed by taking an MD5 of the
      # contents of the entire template file. This ensures that your caches will automatically
      # expire when you change the template file.
      #
      # Note that the MD5 is taken of the entire template file, not just what's within the
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
      #   render "header" translates to render("comments/header")
      #
      #   render(@topic)         translates to render("topics/topic")
      #   render(topics)         translates to render("topics/topic")
      #   render(message.topics) translates to render("topics/topic")
      #
      # It's not possible to derive all render calls like that, though.
      # Here are a few examples of things that can't be derived:
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
      # Sometimes you'll have template dependencies that can't be derived at all. This is typically
      # the case when you have template rendering that happens in helpers. Here's an example:
      #
      #   <%= render_sortable_todolists @project.todolists %>
      #
      # You'll need to use a special comment format to call those out:
      #
      #   <%# Template Dependency: todolists/todolist %>
      #   <%= render_sortable_todolists @project.todolists %>
      #
      # In some cases, like a single table inheritance setup, you might have
      # a bunch of explicit dependencies. Instead of writing every template out,
      # you can use a wildcard to match any template in a directory:
      #
      #   <%# Template Dependency: events/* %>
      #   <%= render_categorizable_events @person.events %>
      #
      # This marks every template in the directory as a dependency. To find those
      # templates, the wildcard path must be absolutely defined from <tt>app/views</tt> or paths
      # otherwise added with +prepend_view_path+ or +append_view_path+.
      # This way the wildcard for <tt>app/views/recordings/events</tt> would be <tt>recordings/events/*</tt> etc.
      #
      # The pattern used to match explicit dependencies is <tt>/# Template Dependency: (\S+)/</tt>,
      # so it's important that you type it out just so.
      # You can only declare one template dependency per line.
      #
      # === External dependencies
      #
      # If you use a helper method, for example, inside a cached block and
      # you then update that helper, you'll have to bump the cache as well.
      # It doesn't really matter how you do it, but the MD5 of the template file
      # must change. One recommendation is to simply be explicit in a comment, like:
      #
      #   <%# Helper Dependency Updated: May 6, 2012 at 6pm %>
      #   <%= some_helper_method(person) %>
      #
      # Now all you have to do is change that timestamp when the helper method changes.
      #
      # === Collection Caching
      #
      # When rendering a collection of objects that each use the same partial, a <tt>:cached</tt>
      # option can be passed.
      #
      # For collections rendered such:
      #
      #   <%= render partial: 'projects/project', collection: @projects, cached: true %>
      #
      # The <tt>cached: true</tt> will make Action View's rendering read several templates
      # from cache at once instead of one call per template.
      #
      # Templates in the collection not already cached are written to cache.
      #
      # Works great alongside individual template fragment caching.
      # For instance if the template the collection renders is cached like:
      #
      #   # projects/_project.html.erb
      #   <% cache project do %>
      #     <%# ... %>
      #   <% end %>
      #
      # Any collection renders will find those cached templates when attempting
      # to read multiple templates at once.
      #
      # If your collection cache depends on multiple sources (try to avoid this to keep things simple),
      # you can name all these dependencies as part of a block that returns an array:
      #
      #   <%= render partial: 'projects/project', collection: @projects, cached: -> project { [ project, current_user ] } %>
      #
      # This will include both records as part of the cache key and updating either of them will
      # expire the cache.
      #
      # === Caching content from `content_for`
      #
      # Content that is captured using `content_for` while inside of a `cache` block will also get
      # written to the cache alongside the fragment content, under the same cache key, and read back
      # from the cache anytime that fragment is read from the cache.
      #
      def cache(name = {}, options = {}, &block)
        if controller.try(:perform_caching)
          @_content_for_to_cache = Hash.new { |h,k| h[k] = ActiveSupport::SafeBuffer.new }
          name_options = options.slice(:skip_digest)
          safe_concat(fragment_for(cache_fragment_name(name, **name_options), options, &block))
        else
          yield
        end

        nil
      ensure
        @_content_for_to_cache = nil
      end

      # Cache fragments of a view if +condition+ is true
      #
      #   <% cache_if admin?, project do %>
      #     <b>All the topics on this project</b>
      #     <%= render project.topics %>
      #   <% end %>
      def cache_if(condition, name = {}, options = {}, &block)
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
      def cache_unless(condition, name = {}, options = {}, &block)
        cache_if !condition, name, options, &block
      end

      # This helper returns the name of a cache key for a given fragment cache
      # call. By supplying <tt>skip_digest: true</tt> to cache, the digestion of cache
      # fragments can be manually bypassed. This is useful when cache fragments
      # cannot be manually expired unless you know the exact key which is the
      # case when using memcached.
      def cache_fragment_name(name = {}, skip_digest: nil, digest_path: nil)
        if skip_digest
          name
        else
          fragment_name_with_digest(name, digest_path)
        end
      end

      def digest_path_from_template(template) # :nodoc:
        digest = Digestor.digest(name: template.virtual_path, format: template.format, finder: lookup_context, dependencies: view_cache_dependencies)

        if digest.present?
          "#{template.virtual_path}:#{digest}"
        else
          template.virtual_path
        end
      end

    private
      def fragment_name_with_digest(name, digest_path)
        name = controller.url_for(name).split("://").last if name.is_a?(Hash)

        if @current_template&.virtual_path || digest_path
          digest_path ||= digest_path_from_template(@current_template)
          [ digest_path, name ]
        else
          name
        end
      end

      def fragment_for(name = {}, options = nil, &block)
        if content = read_fragment_for(name, options)
          @view_renderer.cache_hits[@current_template&.virtual_path] = :hit if defined?(@view_renderer)
          content
        else
          @view_renderer.cache_hits[@current_template&.virtual_path] = :miss if defined?(@view_renderer)
          write_fragment_for(name, options, &block)
        end
      end

      def read_fragment_for(name, options)
        controller.read_fragment(name, options).tap do |cont|
          restore_cached_content_for
        end
      end

      def write_fragment_for(name, options)
        pos = output_buffer.length
        yield
        output_safe = output_buffer.html_safe?
        fragment = output_buffer.slice!(pos..-1)
        if output_safe
          self.output_buffer = output_buffer.class.new(output_buffer)
        end
        value_to_write = {_fragment: fragment}
        value_to_write.merge!(@_content_for_to_cache) if instance_variable_defined?(:@_content_for_to_cache) && @_content_for_to_cache
        controller.write_fragment(name, value_to_write, options)
      end

      def restore_cached_content_for
        return unless controller.try(:perform_caching)

        if controller.cached_content_for.is_a?(Hash)
          controller.cached_content_for.each { |k, v|
            content_for(k, v)
          }
        end
      end
    end
  end
end
