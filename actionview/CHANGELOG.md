## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Pass render options and block to calls to `#render_in`

    ```ruby
    class Greeting
      def render_in(view_context, **options, &block)
        if block
          view_context.render html: block.call
        else
          view_context.render inline: <<~ERB.strip, **options
            Hello, <%= local_assigns.fetch(:name, "World") %>!
          ERB
        end
      end
    end

    render(Greeting.new)                                        # => "Hello, World!"
    render(Greeting.new, name: "Local")                         # => "Hello, Local!"
    render(renderable: Greeting.new, locals: { name: "Local" }) # => "Hello, Local!"
    render(Greeting.new) { "Hello, Block!" }                    # => "Hello, Block!"
    ```

    *Sean Doyle*

*   Enable DependencyTracker to evaluate renders with trailing interpolation.

    ```erb
    <%= render "maintenance_tasks/runs/info/#{run.status}" %>
    ```

    Previously, the DependencyTracker would ignore this render, but now it will
    mark all partials in the "maintenance_tasks/runs/info" folder as
    dependencies.

    *Hartley McGuire*

*   Rename `text_area` methods into `textarea`

    Old names are still available as aliases.

    *Sean Doyle*

*   Rename `check_box*` methods into `checkbox*`.

    Old names are still available as aliases.

    *Jean Boussier*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
