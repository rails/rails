*   Add support for different rate limiting strategies.

    Support multiple strategies in RateLimiting feature.
    Use a custom strategy or switch to `sliding_window` instead of the default `fixed_window`

    Using a pre-defined strategy:
    ```ruby
        class LimitsController < ActionController::Base
        rate_limit to: 10, within: 1.hour, strategy: :sliding_window
        end
    ```
    Using a custom strategy
    ```ruby
        class LimitsController < ActionController::Base
        rate_limit to: 10, within: 1.hour, strategy: ::LeakyBucketStrategy
        end
    ```

    *Federico Aldunate*

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
