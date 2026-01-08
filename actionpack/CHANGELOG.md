## Rails 8.1.2 (January 08, 2026) ##

*   Add `config.action_controller.live_streaming_excluded_keys` to control execution state sharing in ActionController::Live.

    When using ActionController::Live, actions are executed in a separate thread that shares
    state from the parent thread. This new configuration allows applications to opt-out specific
    state keys that should not be shared.

    This is useful when streaming inside a `connected_to` block, where you may want
    the streaming thread to use its own database connection context.

    ```ruby
    # config/application.rb
    config.action_controller.live_streaming_excluded_keys = [:active_record_connected_to_stack]
    ```

    By default, all keys are shared.

    *Eileen M. Uchitelle*

*   Fix `IpSpoofAttackError` message to include `Forwarded` header content.

    Without it, the error message may be misleading.

    *zzak*


## Rails 8.1.1 (October 28, 2025) ##

*   Allow methods starting with underscore to be action methods.

    Disallowing methods starting with an underscore from being action methods
    was an unintended side effect of the performance optimization in
    207a254.

    Fixes #55985.

    *Rafael Mendonça França*


## Rails 8.1.0 (October 22, 2025) ##

*   Submit test requests using `as: :html` with `Content-Type: x-www-form-urlencoded`

    *Sean Doyle*

*   Add link-local IP ranges to `ActionDispatch::RemoteIp` default proxies.

    Link-local addresses (`169.254.0.0/16` for IPv4 and `fe80::/10` for IPv6)
    are now included in the default trusted proxy list, similar to private IP ranges.

    *Adam Daniels*

*   `remote_ip` will no longer ignore IPs in X-Forwarded-For headers if they
    are accompanied by port information.

    *Duncan Brown*, *Prevenios Marinos*, *Masafumi Koba*, *Adam Daniels*

*   Add `action_dispatch.verbose_redirect_logs` setting that logs where redirects were called from.

    Similar to `active_record.verbose_query_logs` and `active_job.verbose_enqueue_logs`, this adds a line in your logs that shows where a redirect was called from.

    Example:

    ```
    Redirected to http://localhost:3000/posts/1
    ↳ app/controllers/posts_controller.rb:32:in `block (2 levels) in create'
    ```

    *Dennis Paagman*

*   Add engine route filtering and better formatting in `bin/rails routes`.

    Allow engine routes to be filterable in the routing inspector, and
    improve formatting of engine routing output.

    Before:
    ```
    > bin/rails routes -e engine_only
    No routes were found for this grep pattern.
    For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html.
    ```

    After:
    ```
    > bin/rails routes -e engine_only
    Routes for application:
    No routes were found for this grep pattern.
    For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html.

    Routes for Test::Engine:
    Prefix Verb URI Pattern       Controller#Action
    engine GET  /engine_only(.:format) a#b
    ```

    *Dennis Paagman*, *Gannon McGibbon*

*   Add structured events for Action Pack and Action Dispatch:
    - `action_dispatch.redirect`
    - `action_controller.request_started`
    - `action_controller.request_completed`
    - `action_controller.callback_halted`
    - `action_controller.rescue_from_handled`
    - `action_controller.file_sent`
    - `action_controller.redirected`
    - `action_controller.data_sent`
    - `action_controller.unpermitted_parameters`
    - `action_controller.fragment_cache`

    *Adrianna Chang*

*   URL helpers for engines mounted at the application root handle `SCRIPT_NAME` correctly.

    Fixed an issue where `SCRIPT_NAME` is not applied to paths generated for routes in an engine
    mounted at "/".

    *Mike Dalessio*

*   Update `ActionController::Metal::RateLimiting` to support passing method names to `:by` and `:with`

    ```ruby
    class SignupsController < ApplicationController
      rate_limit to: 10, within: 1.minute, with: :redirect_with_flash

      private
        def redirect_with_flash
          redirect_to root_url, alert: "Too many requests!"
        end
    end
    ```

    *Sean Doyle*

*   Optimize `ActionDispatch::Http::URL.build_host_url` when protocol is included in host.

    When using URL helpers with a host that includes the protocol (e.g., `{ host: "https://example.com" }`),
    skip unnecessary protocol normalization and string duplication since the extracted protocol is already
    in the correct format. This eliminates 2 string allocations per URL generation and provides a ~10%
    performance improvement for this case.

    *Joshua Young*, *Hartley McGuire*

*   Allow `action_controller.logger` to be disabled by setting it to `nil` or `false` instead of always defaulting to `Rails.logger`.

    *Roberto Miranda*

*   Remove deprecated support to a route to multiple paths.

    *Rafael Mendonça França*

*   Remove deprecated support for using semicolons as a query string separator.

    Before:

    ```ruby
    ActionDispatch::QueryParser.each_pair("foo=bar;baz=quux").to_a
    # => [["foo", "bar"], ["baz", "quux"]]
    ```

    After:

    ```ruby
    ActionDispatch::QueryParser.each_pair("foo=bar;baz=quux").to_a
    # => [["foo", "bar;baz=quux"]]
    ```

    *Rafael Mendonça França*

*   Remove deprecated support to skipping over leading brackets in parameter names in the parameter parser.

    Before:

    ```ruby
    ActionDispatch::ParamBuilder.from_query_string("[foo]=bar") # => { "foo" => "bar" }
    ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz") # => { "foo" => { "bar" => "baz" } }
    ```

    After:

    ```ruby
    ActionDispatch::ParamBuilder.from_query_string("[foo]=bar") # => { "[foo]" => "bar" }
    ActionDispatch::ParamBuilder.from_query_string("[foo][bar]=baz") # => { "[foo]" => { "bar" => "baz" } }
    ```

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.action_dispatch.ignore_leading_brackets`.

    *Rafael Mendonça França*

*   Raise `ActionController::TooManyRequests` error from `ActionController::RateLimiting`

    Requests that exceed the rate limit raise an `ActionController::TooManyRequests` error.
    By default, Action Dispatch rescues the error and responds with a `429 Too Many Requests` status.

    *Sean Doyle*

*   Add .md/.markdown as Markdown extensions and add a default `markdown:` renderer:

    ```ruby
    class Page
      def to_markdown
        body
      end
    end

    class PagesController < ActionController::Base
      def show
        @page = Page.find(params[:id])

        respond_to do |format|
          format.html
          format.md { render markdown: @page }
        end
      end
    end
    ```

    *DHH*

*   Add headers to engine routes inspection command

    *Petrik de Heus*

*   Add "Copy as text" button to error pages

    *Mikkel Malmberg*

*   Add `scope:` option to `rate_limit` method.

    Previously, it was not possible to share a rate limit count between several controllers, since the count was by
    default separate for each controller.

    Now, the `scope:` option solves this problem.

    ```ruby
    class APIController < ActionController::API
      rate_limit to: 2, within: 2.seconds, scope: "api"
    end

    class API::PostsController < APIController
      # ...
    end

    class API::UsersController < APIController
      # ...
    end
    ```

    *ArthurPV*, *Kamil Hanus*

*   Add support for `rack.response_finished` callbacks in ActionDispatch::Executor.

    The executor middleware now supports deferring completion callbacks to later
    in the request lifecycle by utilizing Rack's `rack.response_finished` mechanism,
    when available. This enables applications to define `rack.response_finished` callbacks
    that may rely on state that would be cleaned up by the executor's completion callbacks.

    *Adrianna Chang*, *Hartley McGuire*

*   Produce a log when `rescue_from` is invoked.

    *Steven Webb*, *Jean Boussier*

*   Allow hosts redirects from `hosts` Rails configuration

    ```ruby
    config.action_controller.allowed_redirect_hosts << "example.com"
    ```

    *Kevin Robatel*

*   `rate_limit.action_controller` notification has additional payload

    additional values: count, to, within, by, name, cache_key

    *Jonathan Rochkind*

*   Add JSON support to the built-in health controller.

    The health controller now responds to JSON requests with a structured response
    containing status and timestamp information. This makes it easier for monitoring
    tools and load balancers to consume health check data programmatically.

    ```ruby
    # /up.json
    {
      "status": "up",
      "timestamp": "2025-09-19T12:00:00Z"
    }
    ```

    *Francesco Loreti*, *Juan Vásquez*

*   Allow to open source file with a crash from the browser.

    *Igor Kasyanchuk*

*   Always check query string keys for valid encoding just like values are checked.

    *Casper Smits*

*   Always return empty body for HEAD requests in `PublicExceptions` and
    `DebugExceptions`.

    This is required by `Rack::Lint` (per RFC9110).

    *Hartley McGuire*

*   Add comprehensive support for HTTP Cache-Control request directives according to RFC 9111.

    Provides a `request.cache_control_directives` object that gives access to request cache directives:

    ```ruby
    # Boolean directives
    request.cache_control_directives.only_if_cached?  # => true/false
    request.cache_control_directives.no_cache?        # => true/false
    request.cache_control_directives.no_store?        # => true/false
    request.cache_control_directives.no_transform?    # => true/false

    # Value directives
    request.cache_control_directives.max_age          # => integer or nil
    request.cache_control_directives.max_stale        # => integer or nil (or true for valueless max-stale)
    request.cache_control_directives.min_fresh        # => integer or nil
    request.cache_control_directives.stale_if_error   # => integer or nil

    # Special helpers for max-stale
    request.cache_control_directives.max_stale?         # => true if max-stale present (with or without value)
    request.cache_control_directives.max_stale_unlimited? # => true only for valueless max-stale
    ```

    Example usage:

    ```ruby
    def show
      if request.cache_control_directives.only_if_cached?
        @article = Article.find_cached(params[:id])
        return head(:gateway_timeout) if @article.nil?
      else
        @article = Article.find(params[:id])
      end

      render :show
    end
    ```

    *egg528*

*   Add assert_in_body/assert_not_in_body as the simplest way to check if a piece of text is in the response body.

    *DHH*

*   Include cookie name when calculating maximum allowed size.

    *Hartley McGuire*

*   Implement `must-understand` directive according to RFC 9111.

    The `must-understand` directive indicates that a cache must understand the semantics of the response status code, or discard the response. This directive is enforced to be used only with `no-store` to ensure proper cache behavior.

    ```ruby
    class ArticlesController < ApplicationController
      def show
        @article = Article.find(params[:id])

        if @article.special_format?
          must_understand
          render status: 203 # Non-Authoritative Information
        else
          fresh_when @article
        end
      end
    end
    ```

    *heka1024*

*   The JSON renderer doesn't escape HTML entities or Unicode line separators anymore.

    Using `render json:` will no longer escape `<`, `>`, `&`, `U+2028` and `U+2029` characters that can cause errors
    when the resulting JSON is embedded in JavaScript, or vulnerabilities when the resulting JSON is embedded in HTML.

    Since the renderer is used to return a JSON document as `application/json`, it's typically not necessary to escape
    those characters, and it improves performance.

    Escaping will still occur when the `:callback` option is set, since the JSON is used as JavaScript code in this
    situation (JSONP).

    You can use the `:escape` option or set `config.action_controller.escape_json_responses` to `true` to restore the
    escaping behavior.

    ```ruby
    class PostsController < ApplicationController
      def index
        render json: Post.last(30), escape: true
      end
    end
    ```

    *Étienne Barrié*, *Jean Boussier*

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

*   A route pointing to a non-existing controller now returns a 500 instead of a 404.

    A controller not existing isn't a routing error that should result
    in a 404, but a programming error that should result in a 500 and
    be reported.

    Until recently, this was hard to untangle because of the support
    for dynamic `:controller` segment in routes, but since this is
    deprecated and will be removed in Rails 8.1, we can now easily
    not consider missing controllers as routing errors.

    *Jean Boussier*

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
