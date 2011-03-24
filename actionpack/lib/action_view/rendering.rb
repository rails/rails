require 'active_support/core_ext/object/try'

module ActionView
  # = Action View Rendering
  module Rendering
    # Returns the result of a render that's dictated by the options hash. The primary options are:
    #
    # * <tt>:partial</tt> - See ActionView::Partials.
    # * <tt>:update</tt> - Calls update_page with the block given.
    # * <tt>:file</tt> - Renders an explicit template file (this used to be the old default), add :locals to pass in those.
    # * <tt>:inline</tt> - Renders an inline template similar to how it's done in the controller.
    # * <tt>:text</tt> - Renders the text passed in out.
    # * <tt>:once</tt> - Accepts a string or an array of strings and Rails will ensure they each of them are rendered just once.
    #
    # If no options hash is passed or :update specified, the default is to render a partial and use the second parameter
    # as the locals hash.
    def render(options = {}, locals = {}, &block)
      case options
      when Hash
        if block_given?
          _render_partial(options.merge(:partial => options[:layout]), &block)
        elsif options.key?(:partial)
          _render_partial(options)
        elsif options.key?(:once)
          _render_once(options)
        else
          _render_template(options)
        end
      when :update
        update_page(&block)
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

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
        @_content_for[name].html_safe
      elsif block
        capture(*args, &block)
      else
        @_content_for[:layout].html_safe
      end
    end

    def _render_once(options) #:nodoc:
      _template_renderer.render_once(options)
    end

    def _render_template(options) #:nodoc:
      _template_renderer.render(options)
    end

    def _template_renderer #:nodoc:
      @_template_renderer ||= TemplateRenderer.new(self)
    end
  end
end
