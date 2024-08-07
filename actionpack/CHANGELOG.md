*   Speed up `ActionDispatch::Routing::Mapper::Scope#[]` by merging frame hashes.

    *Gannon McGibbon*

*   Allow bots to ignore `allow_browser`.

    *Matthew Nguyen*

*   Deprecate drawing routes with hash key paths to make routing faster.

    ```ruby
    # Before
    get "/users" => "users#index"
    post "/logout" => :sessions
    mount MyApp => "/my_app"

    # After
    get "/users", to: "users#index"
    post "/logout", to: "sessions#logout"
    mount MyApp, at: "/my_app"
    ```

    *Gannon McGibbon*

*   Deprecate drawing routes with multiple paths to make routing faster.
    You may use `with_options` or a loop to make drawing multiple paths easier.

    ```ruby
    # Before
    get "/users", "/other_path", to: "users#index"

    # After
    get "/users", to: "users#index"
    get "/other_path", to: "users#index"
    ```

    *Gannon McGibbon*

*   Make `http_cache_forever` use `immutable: true`

    *Nate Matykiewicz*

*   Add `config.action_dispatch.strict_freshness`.

    When set to `true`, the `ETag` header takes precedence over the `Last-Modified` header when both are present,
    as specified by RFC 7232, Section 6.

    Defaults to `false` to maintain compatibility with previous versions of Rails, but is enabled as part of
    Rails 8.0 defaults.

    *heka1024*

*   Support `immutable` directive in Cache-Control

    ```ruby
    expires_in 1.minute, public: true, immutable: true
    # Cache-Control: public, max-age=60, immutable
    ```

    *heka1024*

*   Add `:wasm_unsafe_eval` mapping for `content_security_policy`

    ```ruby
    # Before
    policy.script_src "'wasm-unsafe-eval'"

    # After
    policy.script_src :wasm_unsafe_eval
    ```

    *Joe Haig*

*   Add `display_capture` and `keyboard_map` in `permissions_policy`

    *Cyril Blaecke*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionpack/CHANGELOG.md) for previous changes.
