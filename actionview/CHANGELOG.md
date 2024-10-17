*   Fallback to rendering partial without controller namespace prefix when available

    When `config.action_view.prefix_partial_path_with_controller_namespace =
    true` and a root-level partial exists, fallback to rendering the partial:

    ```erb
    <%# app/views/articles/_article.html.erb %>
    Rendered
    ```

    ```ruby
    # app/controllers/articles_controller.rb
    class ArticlesController < ApplicationController
      def show
        render partial: Article.find(params[:id])
        # => "Rendered"
      end
    end

    # app/controllers/scoped/articles_controller.rb
    class Scoped::ArticlesController < ApplicationController
      def show
        render partial: Article.find(params[:id])
        # => "Rendered"
      end
    end
    ```

    *Sean Doyle*

## Rails 8.0.0.beta1 (September 26, 2024) ##

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
