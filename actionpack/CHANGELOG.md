*   Accept render options and block in `render` calls made with `:renderable`

    ```ruby
    class Greeting
      def render_in(view_context, **)
        if block_given?
          view_context.render(html: yield)
        else
          view_context.render(inline: <<~ERB.strip, **)
            Hello, <%= local_assigns[:name] || "World" %>
          ERB
        end
      end
    end

    ApplicationController.render(Greeting.new)                                        # => "Hello, World"
    ApplicationController.render(Greeting.new) { "Hello, Block" }                     # => "Hello, Block"
    ApplicationController.render(renderable: Greeting.new)                            # => "Hello, World"
    ApplicationController.render(renderable: Greeting.new, locals: { name: "Local" }) # => "Hello, Local"
    ```

    *Sean Doyle*

*   Add `check_collisions` option to `ActionDispatch::Session::CacheStore`.

    Newly generated session ids use 128 bits of randomness, which is more than
    enough to ensure collisions can't happen, but if you need to harden sessions
    even more, you can enable this option to check in the session store that the id
    is indeed free you can enable that option. This however incurs an extra write
    on session creation.

    *Shia*

*   In ExceptionWrapper, match backtrace lines with built templates more often,
    allowing improved highlighting of errors within do-end blocks in templates.
    Fix for Ruby 3.4 to match new method labels in backtrace.

    *Martin Emde*

*   Allow setting content type with a symbol of the Mime type.

    ```ruby
    # Before
    response.content_type = "text/html"

    # After
    response.content_type = :html
    ```

    *Petrik de Heus*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionpack/CHANGELOG.md) for previous changes.
