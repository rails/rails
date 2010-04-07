module ActionView
  module Layouts
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
    #
    # If self.formats contains several formats, just the first one is considered in
    # the layout lookup.
    def find_layout(layout)
      begin
        if formats.size == 1
          _find_layout(layout)
        else
          update_details(:formats => self.formats.first){ _find_layout(layout) }
        end
      rescue ActionView::MissingTemplate => e
        update_details(:formats => nil) do
          raise unless template_exists?(layout)
        end
      end
    end

    def _find_layout(layout) #:nodoc:
      layout =~ /^\// ?
        with_fallbacks { find_template(layout) } : find_template(layout)
    end

    # Contains the logic that actually renders the layout.
    def _render_layout(layout, locals, &block) #:nodoc:
      layout.render(self, locals){ |*name| _layout_for(*name, &block) }
    end
  end
end
