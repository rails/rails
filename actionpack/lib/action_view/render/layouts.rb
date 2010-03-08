require 'active_support/core_ext/object/try'

module ActionView
  module Layouts

    # You can think of a layout as a method that is called with a block. _layout_for
    # returns the contents that are yielded to the layout. If the user calls yield
    # :some_name, the block, by default, returns content_for(:some_name). If the user
    # calls yield, the default block returns content_for(:layout).
    #
    # The user can override this default by passing a block to the layout.
    #
    # ==== Example
    #
    #   # The template
    #   <% render :layout => "my_layout" do %>Content<% end %>
    #
    #   # The layout
    #   <html><% yield %></html>
    #
    # In this case, instead of the default block, which would return content_for(:layout),
    # this method returns the block that was passed in to render layout, and the response
    # would be <html>Content</html>.
    #
    # Finally, the block can take block arguments, which can be passed in by yield.
    #
    # ==== Example
    #
    #   # The template
    #   <% render :layout => "my_layout" do |customer| %>Hello <%= customer.name %><% end %>
    #
    #   # The layout
    #   <html><% yield Struct.new(:name).new("David") %></html>
    #
    # In this case, the layout would receive the block passed into <tt>render :layout</tt>,
    # and the Struct specified in the layout would be passed into the block. The result
    # would be <html>Hello David</html>.
    def _layout_for(name = nil, &block) #:nodoc:
      if !block || name
        @_content_for[name || :layout]
      else
        capture(&block)
      end
    end

    # This is the method which actually finds the layout using details in the lookup
    # context object. If no layout is found, it checkes if at least a layout with
    # the given name exists across all details before raising the error.
    def _find_layout(layout) #:nodoc:
      begin
        layout =~ /^\// ?
          with_fallbacks { find(layout) } : find(layout)
      rescue ActionView::MissingTemplate => e
        update_details(:formats => nil) do
          raise unless exists?(layout)
        end
      end
    end

    # Contains the logic that actually renders the layout.
    def _render_layout(layout, locals, &block) #:nodoc:
      layout.render(self, locals){ |*name| _layout_for(*name, &block) }
    end
  end
end
