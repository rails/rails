*   Add `ActionDispatch::Request#bearer_token` to extract the bearer token from the Authorization header.
    Bearer tokens are commonly used for API and MCP requests.

    *DHH*

*   Add block support to `ActionController::Parameters#merge`

    `ActionController::Parameters#merge` now accepts a block to resolve conflicts,
    consistent with `Hash#merge` and `Parameters#merge!`.

    ```ruby
    params1 = ActionController::Parameters.new(a: 1, b: 2)
    params2 = ActionController::Parameters.new(b: 3, c: 4)
    params1.merge(params2) { |key, old_val, new_val| old_val + new_val }
    # => #<ActionController::Parameters {"a"=>1, "b"=>5, "c"=>4} permitted: false>
    ```

    *Said Kaldybaev*

*   Yield key to `ActionController::Parameters#fetch` block

    ```ruby
    key = params.fetch(:missing) { |missing_key| missing_key }
    key # => :missing

    key = params.fetch("missing") { |missing_key| missing_key }
    key # => "missing"
    ```

    *Sean Doyle*

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

*   Add controller action source location to routes inspector.

    The routes inspector now shows where controller actions are defined.
    In `rails routes --expanded`, a new "Action Location" field displays
    the file and line number of each action method.

    On the routing error page, when `RAILS_EDITOR` or `EDITOR` is set,
    a clickable ✏️ icon appears next to each Controller#Action that opens
    the action directly in the editor.

    *Guillermo Iguaran*

*   Active Support notifications for CSRF warnings.

    Switches from direct logging to event-driven logging, allowing others to
    subscribe to and act on CSRF events:

    - `csrf_token_fallback.action_controller`
    - `csrf_request_blocked.action_controller`
    - `csrf_javascript_blocked.action_controller`

    *Jeremy Daer*

*   Modern header-based CSRF protection.

    Modern browsers send the `Sec-Fetch-Site` header to indicate the relationship
    between request initiator and target origins. Rails now uses this header to
    verify same-origin requests without requiring authenticity tokens.

    Two verification strategies are available via `protect_from_forgery using:`:

    * `:header_only` - Uses `Sec-Fetch-Site` header only. Rejects requests
      without a valid header. Default for new Rails 8.2 applications.

    * `:header_or_legacy_token` - Uses `Sec-Fetch-Site` header when present,
      falls back to authenticity token verification for older browsers.

    Configure trusted origins for legitimate cross-site requests (OAuth callbacks,
    third-party embeds) with `trusted_origins:`:

    ```ruby
    protect_from_forgery trusted_origins: %w[ https://accounts.google.com ]
    ```

    `InvalidAuthenticityToken` is deprecated in favor of `InvalidCrossOriginRequest`.

    *Rosa Gutierrez*

*   Fix `action_dispatch_request` early load hook call when building
    Rails app middleware.

    *Gannon McGibbon*

*   Emit a structured event when `action_on_open_redirect` is set to `:notify`
    in addition to the existing Active Support Notification.

    *Adrianna Chang*, *Hartley McGuire*

*   Support `text/markdown` format in `DebugExceptions` middleware.

    When `text/markdown` is requested via the Accept header, error responses
    are returned with `Content-Type: text/markdown` instead of HTML.
    The existing text templates are reused for markdown output, allowing
    CLI tools and other clients to receive byte-efficient error information.

    *Guillermo Iguaran*

*   Support dynamic `to:` and `within:` options in `rate_limit`.

    The `to:` and `within:` options now accept callables (lambdas or procs) and
    method names (as symbols), in addition to static values. This allows for
    dynamic rate limiting based on user attributes or other runtime conditions.

    ```ruby
    class APIController < ApplicationController
      rate_limit to: :max_requests, within: :time_window, by: -> { current_user.id }

      private
        def max_requests
          current_user.premium? ? 1000 : 100
        end

        def time_window
          current_user.premium? ? 1.hour : 1.minute
        end
    end
    ```

    *Murilo Duarte*

*   Define `ActionController::Parameters#deconstruct_keys` to support pattern matching

    ```ruby
    if params in { search:, page: }
      Article.search(search).limit(page)
    else
      …
    end

    case (value = params[:string_or_hash_with_nested_key])
    in String
      # do something with a String `value`…
    in { nested_key: }
      # do something with `nested_key` or `value`
    else
      # …
    end
    ```

    *Sean Doyle*

*   Submit test requests using `as: :html` with `Content-Type: x-www-form-urlencoded`

    *Sean Doyle*

*   Add `svg:` renderer:

    ```ruby
    class Page
      def to_svg
        body
      end
    end

    class PagesController < ActionController::Base
      def show
        @page = Page.find(params[:id])

        respond_to do |format|
          format.html
          format.svg { render svg: @page }
        end
      end
    end
    ```

    *Thiago Youssef*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionpack/CHANGELOG.md) for previous changes.
