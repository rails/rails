module ActionView
  module CompiledTemplates #:nodoc:
    # holds compiled template code
  end

  # = Action View Context
  #
  # Action View contexts are supplied to Action Controller to render template.
  # The default Action View context is ActionView::Base.
  #
  # In order to work with ActionController, a Context must just include this module.
  module Context
    include CompiledTemplates
    attr_accessor :output_buffer, :view_flow

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
    def _layout_for(*args, &block)
      name = args.first

      if name.is_a?(Symbol)
        view_flow.get(name).html_safe
      elsif block
        # TODO Import capture into AV::Context or
        # leave it as implicit dependency?
        capture(*args, &block)
      else
        view_flow.get(:layout).html_safe
      end
    end
  end
end