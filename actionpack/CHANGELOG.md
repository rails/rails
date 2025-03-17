*   Add new DSL for Reporting-Endpoints HTTP response header.

    Allows application owners to configure endpoints for the header
    on an application wide or per-request basis.

    ```ruby
    Rails.application.config.reporting_endpoints do |reporting_endpoints|
      reporting_endpoints.endpoints = {
        "csp-reports": "/csp-reports",
        "other-reports": "https://reporting.endpoint.com"
      }
    end
    ```

    ```ruby
    class MyController < ApplicationController
      reporting_endpoints(only: :index) do |config|
        config.endpoints = {
          "csp-reports": "/csp-reports",
          "other": "https://reporting.endpoint.com"
        }
      end
    end
    ```

    *Zack Deveau*

*   Load lazy route sets before inserting test routes

    Without loading lazy route sets early, we miss `after_routes_loaded` callbacks, or risk
    invoking them with the test routes instead of the real ones if another load is triggered by an engine.

    *Gannon McGibbon*

*   Raise `AbstractController::DoubleRenderError` if `head` is called after rendering.

    After this change, invoking `head` will lead to an error if response body is already set:

    ```ruby
    class PostController < ApplicationController
      def index
        render locals: {}
        head :ok
      end
    end
    ```

    *Iaroslav Kurbatov*

*   The Cookie Serializer can now serialize an Active Support SafeBuffer when using message pack.

    Such code would previously produce an error if an application was using messagepack as its cookie serializer.

    ```ruby
    class PostController < ApplicationController
      def index
        flash.notice = t(:hello_html) # This would try to serialize a SafeBuffer, which was not possible.
      end
    end
    ```

    *Edouard Chin*

*   Fix `Rails.application.reload_routes!` from clearing almost all routes.

    When calling `Rails.application.reload_routes!` inside a middleware of
    a Rake task, it was possible under certain conditions that all routes would be cleared.
    If ran inside a middleware, this would result in getting a 404 on most page you visit.
    This issue was only happening in development.

    *Edouard Chin*

*   Add resource name to the `ArgumentError` that's raised when invalid `:only` or `:except` options are given to `#resource` or `#resources`

    This makes it easier to locate the source of the problem, especially for routes drawn by gems.

    Before:
    ```
    :only and :except must include only [:index, :create, :new, :show, :update, :destroy, :edit], but also included [:foo, :bar]
    ```

    After:
    ```
    Route `resources :products` - :only and :except must include only [:index, :create, :new, :show, :update, :destroy, :edit], but also included [:foo, :bar]
    ```

    *Jeremy Green*

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
