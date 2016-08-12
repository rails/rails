*   Show cache hits and misses when rendering partials.

    Partials using the `cache` helper will show whether a render hit or missed
    the cache:

    ```
    Rendered messages/_message.html.erb in 1.2 ms [cache hit]
    Rendered recordings/threads/_thread.html.erb in 1.5 ms [cache miss]
    ```

    This removes the need for the old fragment cache logging:

    ```
    Read fragment views/v1/2914079/v1/2914079/recordings/70182313-20160225015037000000/d0bdf2974e1ef6d31685c3b392ad0b74 (0.6ms)
    Rendered messages/_message.html.erb in 1.2 ms [cache hit]
    Write fragment views/v1/2914079/v1/2914079/recordings/70182313-20160225015037000000/3b4e249ac9d168c617e32e84b99218b5 (1.1ms)
    Rendered recordings/threads/_thread.html.erb in 1.5 ms [cache miss]
    ```

    Though that full output can be reenabled with
    `config.action_controller.enable_fragment_cache_logging = true`.

    *Stan Lo*

*   Don't override the `Accept` header in integration tests when called with `xhr: true`.

    Fixes #25859.

    *David Chen*

*   Fix `defaults` option for root route.

    A regression from some refactoring for the 5.0 release, this change
    fixes the use of `defaults` (default parameters) in the `root` routing method.

    *Chris Arcand*

*   Check `request.path_parameters` encoding at the point they're set.

    Check for any non-UTF8 characters in path parameters at the point they're
    set in `env`. Previously they were checked for when used to get a controller
    class, but this meant routes that went directly to a Rack app, or skipped
    controller instantiation for some other reason, had to defend against
    non-UTF8 characters themselves.

    *Grey Baker*

*   Don't raise `ActionController::UnknownHttpMethod` from `ActionDispatch::Static`.

    Pass `Rack::Request` objects to `ActionDispatch::FileHandler` to avoid it
    raising `ActionController::UnknownHttpMethod`. If an unknown method is
    passed, it should pass exception higher in the stack instead, once we've had a
    chance to define exception handling behaviour.

    *Grey Baker*

*   Handle `Rack::QueryParser` errors in `ActionDispatch::ExceptionWrapper`.

    Updated `ActionDispatch::ExceptionWrapper` to handle the Rack 2.0 namespace
    for `ParameterTypeError` and `InvalidParameterError` errors.

    *Grey Baker*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md) for previous changes.
