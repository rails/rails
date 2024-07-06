*   Add `action_dispatch.verbose_redirect_logs` setting that logs where redirects were called from.

    Similar to `active_record.verbose_query_logs` and `active_job.verbose_enqueue_logs`, this adds a line in your logs that shows
    where a redirect was called from.

    Example:

    ```
    Redirected to http://localhost:3000/posts/1
    ↳ app/controllers/posts_controller.rb:32:in `block (2 levels) in create'
    ```

    *Dennis Paagman*

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
