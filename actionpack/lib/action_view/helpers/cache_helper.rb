module ActionView
  module Helpers
    # This helper to exposes a method for caching of view fragments.
    # See ActionController::Caching::Fragments for usage instructions.
    module CacheHelper
      # A method for caching fragments of a view rather than an entire
      # action or page.  This technique is useful caching pieces like
      # menus, lists of news topics, static HTML fragments, and so on.
      # This method takes a block that contains the content you wish
      # to cache.  See ActionController::Caching::Fragments for more
      # information.
      #
      # ==== Examples
      # If you wanted to cache a navigation menu, you could do the
      # following.
      #
      #   <% cache do %>
      #     <%= render :partial => "menu" %>
      #   <% end %>
      #
      # You can also cache static content...
      #
      #   <% cache do %>
      #      <p>Hello users!  Welcome to our website!</p>
      #   <% end %>
      #
      # ...and static content mixed with RHTML content.
      #
      #    <% cache do %>
      #      Topics:
      #      <%= render :partial => "topics", :collection => @topic_list %>
      #      <i>Topics listed alphabetically</i>
      #    <% end %>
      def cache(name = {}, &block)
        template_extension = first_render[/\.(\w+)$/, 1].to_sym
        case template_extension
        when :erb, :rhtml
          @controller.cache_erb_fragment(block, name)
        when :rjs
          @controller.cache_rjs_fragment(block, name)
        when :builder, :rxml
          @controller.cache_rxml_fragment(block, name)
        else
          # do a last ditch effort for those brave souls using
          # different template engines. This should give plugin
          # writters a simple hook.
          raise "fragment caching not supported for #{template_extension} files." unless @controller.respond_to?("cache_#{template_extension}_fragment")
          @controller.send "cache_#{template_extension}_fragment", block, name
        end
      end
    end
  end
end
