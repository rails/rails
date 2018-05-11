module ActionView
  module Helpers
    # = Action View Rendering
    #
    # Implements methods that allow rendering from a view context.
    # In order to use this module, all you need is to implement
    # view_renderer that returns an ActionView::Renderer object.
    module RenderingHelper
      # Returns the result of a render that's dictated by the options hash. The primary options are:
      #
      # * <tt>:partial</tt> - See <tt>ActionView::PartialRenderer</tt>.
      # * <tt>:file</tt> - Renders an explicit template file (this used to be the old default), add :locals to pass in those.
      # * <tt>:inline</tt> - Renders an inline template similar to how it's done in the controller.
      # * <tt>:plain</tt> - Renders the text passed in out. Setting the content
      #   type as <tt>text/plain</tt>.
      # * <tt>:html</tt> - Renders the HTML safe string passed in out, otherwise
      #   performs HTML escape on the string first. Setting the content type as
      #   <tt>text/html</tt>.
      # * <tt>:body</tt> - Renders the text passed in, and inherits the content
      #   type of <tt>text/plain</tt> from <tt>ActionDispatch::Response</tt>
      #   object.
      #
      # If no options hash is passed or :update specified, the default is to render a partial and use the second parameter
      # as the locals hash.
      def render(options = {}, locals = {}, &block)
        case options
        when Hash
          if block_given?
            view_renderer.render_partial(self, options.merge(partial: options[:layout]), &block)
          else
            view_renderer.render(self, options)
          end
        else
          view_renderer.render_partial(self, partial: options, locals: locals, &block)
        end
      end

      # Overwrites _layout_for in the context object so it supports the case a block is
      # passed to a partial. Returns the contents that are yielded to a layout, given a
      # name or a block.
      #
      # You can think of a layout as a method that is called with a block. If the user calls
      # <tt>yield :some_name</tt>, the block, by default, returns <tt>content_for(:some_name)</tt>.
      # If the user calls simply +yield+, the default block returns <tt>content_for(:layout)</tt>.
      #
      # The user can override this default by passing a block to the layout:
      #
      #   # The template
      #   <%= render layout: "my_layout" do %>
      #     Content
      #   <% end %>
      #
      #   # The layout
      #   <html>
      #     <%= yield %>
      #   </html>
      #
      # In this case, instead of the default block, which would return <tt>content_for(:layout)</tt>,
      # this method returns the block that was passed in to <tt>render :layout</tt>, and the response
      # would be
      #
      #   <html>
      #     Content
      #   </html>
      #
      # Finally, the block can take block arguments, which can be passed in by +yield+:
      #
      #   # The template
      #   <%= render layout: "my_layout" do |customer| %>
      #     Hello <%= customer.name %>
      #   <% end %>
      #
      #   # The layout
      #   <html>
      #     <%= yield Struct.new(:name).new("David") %>
      #   </html>
      #
      # In this case, the layout would receive the block passed into <tt>render :layout</tt>,
      # and the struct specified would be passed into the block as an argument. The result
      # would be
      #
      #   <html>
      #     Hello David
      #   </html>
      #
      def _layout_for(*args, &block)
        name = args.first

        if block && !name.is_a?(Symbol)
          capture(*args, &block)
        else
          super
        end
      end
    end
  end
end
