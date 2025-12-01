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

*   Add ability to pass a block when rendering collection. The block will be executed for each rendered element in the collection.

    *Vincent Robert*

*   Add `key:` and `expires_in:` options under `cached:` to `render` when used with `collection:`

    *Jarrett Lusso*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionview/CHANGELOG.md) for previous changes.
