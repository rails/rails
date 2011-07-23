module ActionView
  # = Action View Cache Helper
  module Helpers
    module CacheHelper
      # This helper to exposes a method for caching of view fragments.
      # See ActionController::Caching::Fragments for usage instructions.
      #
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
          if output_buffer.html_safe?
            safe_output_buffer = output_buffer.to_str
            fragment = safe_output_buffer.slice!(pos..-1)
            self.output_buffer = output_buffer.class.new(safe_output_buffer)
          else
            fragment = output_buffer.slice!(pos..-1)
          end
          controller.write_fragment(name, fragment, options)
        end
      end
    end
  end
end
