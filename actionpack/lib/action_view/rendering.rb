require 'active_support/core_ext/object/try'

module ActionView
  # = Action View Rendering
  module Rendering
    # This is temporary until we remove the renderer dependency from AV.
    delegate :render, :render_body, :to => :@_renderer

    # Returns the contents that are yielded to a layout, given a name or a block.
    #
    # You can think of a layout as a method that is called with a block. If the user calls
    # <tt>yield :some_name</tt>, the block, by default, returns <tt>content_for(:some_name)</tt>.
    # If the user calls simply +yield+, the default block returns <tt>content_for(:layout)</tt>.
    #
    # The user can override this default by passing a block to the layout:
    #
    #   # The template
    #   <%= render :layout => "my_layout" do %>
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
    #   <%= render :layout => "my_layout" do |customer| %>
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
    def _layout_for(*args)
      name = args.first
      name = :layout unless name.is_a?(Symbol)
      @_view_flow.get(name).html_safe
    end

    # Handle layout for calls from partials that supports blocks.
    def _block_layout_for(*args, &block)
      name = args.first

      if !name.is_a?(Symbol) && block
        capture(*args, &block)
      else
        _layout_for(*args)
      end
    end
  end
end
