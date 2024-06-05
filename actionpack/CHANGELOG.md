*   Implement `Http::Headers#http` that returns the original HTTP headers

    ```ruby
    # Before
    request.headers.env
      .select { |key, _value| key.start_with?("HTTP_") }
      .transform_keys { |key| key.sub(/^HTTP_/, "").split("_").map(&:capitalize).join("-") }

    # After
    request.headers.http
    ```

    *Matija Čupić*

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
