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

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md) for previous changes.
