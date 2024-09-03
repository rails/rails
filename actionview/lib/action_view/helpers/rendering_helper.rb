# frozen_string_literal: true

# :markup: markdown

module ActionView
  module Helpers # :nodoc:
    # # Action View Rendering Helpers
    #
    # Implements methods that allow rendering from a view context. In order to use
    # this module, all you need is to implement view_renderer that returns an
    # ActionView::Renderer object.
    module RenderingHelper
      # Renders a template and returns the result.
      #
      # Pass the template to render as the first argument. This is shorthand
      # syntax for partial rendering, so the template filename should be
      # prefixed with an underscore. The partial renderer looks for the partial
      # template in the directory of the calling template first.
      #
      #     <% # app/views/posts/new.html.erb %>
      #     <%= render "form" %>
      #     # => renders app/views/posts/_form.html.erb
      #
      # Use the complete view path to render a partial from another directory.
      #
      #     <% # app/views/posts/show.html.erb %>
      #     <%= render "comments/form" %>
      #     # => renders app/views/comments/_form.html.erb
      #
      # Without the rendering mode, the second argument can be a Hash of local
      # variable assignments for the template.
      #
      #     <% # app/views/posts/new.html.erb %>
      #     <%= render "form", post: Post.new %>
      #     # => renders app/views/posts/_form.html.erb
      #
      # If the first argument responds to `render_in`, the template will be rendered
      # by calling `render_in` with the current view context.
      #
      #     class Greeting
      #       def render_in(view_context)
      #         view_context.render html: "<h1>Hello, World</h1>"
      #       end
      #
      #       def format
      #         :html
      #       end
      #     end
      #
      #     <%= render Greeting.new %>
      #     # => "<h1>Hello, World</h1>"
      #
      # #### Rendering Mode
      #
      # Pass the rendering mode as first argument to override it.
      #
      # `:partial`
      # :   See ActionView::PartialRenderer for details.
      #
      #         <%= render partial: "form", locals: { post: Post.new } %>
      #         # => renders app/views/posts/_form.html.erb
      #
      # `:file`
      # :   Renders the contents of a file. This option should **not** be used with
      #     unsanitized user input.
      #
      #         <%= render file: "/path/to/some/file" %>
      #         # => renders /path/to/some/file
      #
      # `:inline`
      # :   Renders an ERB template string.
      #
      #         <% name = "World" %>
      #         <%= render inline: "<h1>Hello, <%= name %>!</h1>" %>
      #         # => renders "<h1>Hello, World!</h1>"
      #
      # `:body`
      # :   Renders the provided text, and sets the format as `:text`.
      #
      #         <%= render body: "Hello, World!" %>
      #         # => renders "Hello, World!"
      #
      # `:plain`
      # :   Renders the provided text, and sets the format as `:text`.
      #
      #         <%= render plain: "Hello, World!" %>
      #         # => renders "Hello, World!"
      #
      # `:html`
      # :   Renders the provided HTML string, and sets the format as
      #     `:html`. If the string is not `html_safe?`, performs HTML escaping on
      #     the string before rendering.
      #
      #         <%= render html: "<h1>Hello, World!</h1>".html_safe %>
      #         # => renders "<h1>Hello, World!</h1>"
      #
      #         <%= render html: "<h1>Hello, World!</h1>" %>
      #         # => renders "&lt;h1&gt;Hello, World!&lt;/h1&gt;"
      #
      # `:renderable`
      # :   Renders the provided object by calling `render_in` with the current view
      #     context. The format is determined by calling `format` on the
      #     renderable if it responds to `format`, falling back to `:html` by
      #     default.
      #
      #         <%= render renderable: Greeting.new %>
      #         # => renders "<h1>Hello, World</h1>"
      #
      #
      # #### Options
      #
      # `:locals`
      # :   Hash of local variable assignments for the template.
      #
      #         <%= render inline: "<h1>Hello, <%= name %>!</h1>", locals: { name: "World" } %>
      #         # => renders "<h1>Hello, World!</h1>"
      #
      # `:formats`
      # :   Override the current format to render a template for a different format.
      #
      #         <% # app/views/posts/show.html.erb %>
      #         <%= render template: "posts/content", formats: [:text] %>
      #         # => renders app/views/posts/content.text.erb
      #
      # `:variants`
      # :   Render a template for a different variant.
      #
      #         <% # app/views/posts/show.html.erb %>
      #         <%= render template: "posts/content", variants: [:tablet] %>
      #         # => renders app/views/posts/content.html+tablet.erb
      #
      # `:handlers`
      # :   Render a template for a different handler.
      #
      #         <% # app/views/posts/show.html.erb %>
      #         <%= render template: "posts/content", handlers: [:builder] %>
      #         # => renders app/views/posts/content.html.builder
      def render(options = {}, locals = {}, &block)
        case options
        when Hash
          in_rendering_context(options) do |renderer|
            if block_given?
              view_renderer.render_partial(self, options.merge(partial: options[:layout]), &block)
            else
              view_renderer.render(self, options)
            end
          end
        else
          if options.respond_to?(:render_in)
            options.render_in(self, &block)
          else
            view_renderer.render_partial(self, partial: options, locals: locals, &block)
          end
        end
      end

      # Overrides _layout_for in the context object so it supports the case a block is
      # passed to a partial. Returns the contents that are yielded to a layout, given
      # a name or a block.
      #
      # You can think of a layout as a method that is called with a block. If the user
      # calls `yield :some_name`, the block, by default, returns
      # `content_for(:some_name)`. If the user calls simply `yield`, the default block
      # returns `content_for(:layout)`.
      #
      # The user can override this default by passing a block to the layout:
      #
      #     # The template
      #     <%= render layout: "my_layout" do %>
      #       Content
      #     <% end %>
      #
      #     # The layout
      #     <html>
      #       <%= yield %>
      #     </html>
      #
      # In this case, instead of the default block, which would return `content_for(:layout)`,
      # this method returns the block that was passed in to `render :layout`, and the response
      # would be
      #
      #     <html>
      #       Content
      #     </html>
      #
      # Finally, the block can take block arguments, which can be passed in by
      # `yield`:
      #
      #     # The template
      #     <%= render layout: "my_layout" do |customer| %>
      #       Hello <%= customer.name %>
      #     <% end %>
      #
      #     # The layout
      #     <html>
      #       <%= yield Struct.new(:name).new("David") %>
      #     </html>
      #
      # In this case, the layout would receive the block passed into `render :layout`,
      # and the struct specified would be passed into the block as an argument. The result
      # would be
      #
      #     <html>
      #       Hello David
      #     </html>
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
