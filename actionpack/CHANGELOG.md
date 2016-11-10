*   Add `ActionController::Parameters#merge!`, which behaves the same as `Hash#merge!`.

    *Yuji Yaginuma*

*   Allow keys not found in RACK_KEY_TRANSLATION for setting the environment when rendering
    arbitrary templates.

    *Sammy Larbi*

*   Remove deprecated support to non-keyword arguments in `ActionDispatch::IntegrationTest#process`,
    `#get`, `#post`, `#patch`, `#put`, `#delete`, and `#head`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::IntegrationTest#*_via_redirect`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::IntegrationTest#xml_http_request`.

    *Rafael Mendonça França*

*   Remove deprecated support for passing `:path` and route path as strings in `ActionDispatch::Routing::Mapper#match`.

    *Rafael Mendonça França*

*   Remove deprecated support for passing path as `nil` in `ActionDispatch::Routing::Mapper#match`.

    *Rafael Mendonça França*

*   Remove deprecated `cache_control` argument from `ActionDispatch::Static#initialize`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing strings or symbols to the middleware stack.

    *Rafael Mendonça França*

*   Change HSTS subdomain to true.

    *Rafael Mendonça França*

*   Remove deprecated `host` and `port` ssl options.

    *Rafael Mendonça França*

*   Remove deprecated `const_error` argument in
    `ActionDispatch::Session::SessionRestoreError#initialize`.

    *Rafael Mendonça França*

*   Remove deprecated `#original_exception` in `ActionDispatch::Session::SessionRestoreError`.

    *Rafael Mendonça França*

*   Deprecate `ActionDispatch::ParamsParser::ParseError` in favor of
    `ActionDispatch::Http::Parameters::ParseError`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::ParamsParser`.

    *Rafael Mendonça França*

*   Remove deprecated `original_exception` and `message` arguments in
    `ActionDispatch::ParamsParser::ParseError#initialize`.

    *Rafael Mendonça França*

*   Remove deprecated `#original_exception` in `ActionDispatch::ParamsParser::ParseError`.

    *Rafael Mendonça França*

*   Remove deprecated access to mime types through constants.

    *Rafael Mendonça França*

*   Remove deprecated support to non-keyword arguments in `ActionController::TestCase#process`,
    `#get`, `#post`, `#patch`, `#put`, `#delete`, and `#head`.

    *Rafael Mendonça França*

*   Remove deprecated `xml_http_request` and `xhr` methods in `ActionController::TestCase`.

    *Rafael Mendonça França*

*   Remove deprecated methods in `ActionController::Parameters`.

    *Rafael Mendonça França*

*   Remove deprecated support to comparing a `ActionController::Parameters`
    with a `Hash`.

    *Rafael Mendonça França*

*   Remove deprecated support to `:text` in `render`.

    *Rafael Mendonça França*

*   Remove deprecated support to `:nothing` in `render`.

    *Rafael Mendonça França*

*   Remove deprecated support to `:back` in `redirect_to`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing status as option `head`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing original exception to `ActionController::BadRequest`
    and the `ActionController::BadRequest#original_exception` method.

    *Rafael Mendonça França*

*   Remove deprecated methods `skip_action_callback`, `skip_filter`, `before_filter`,
    `prepend_before_filter`, `skip_before_filter`, `append_before_filter`, `around_filter`
    `prepend_around_filter`, `skip_around_filter`, `append_around_filter`, `after_filter`,
    `prepend_after_filter`, `skip_after_filter` and `append_after_filter`.

    *Rafael Mendonça França*

*   Show an "unmatched constraints" error when params fail to match constraints
    on a matched route, rather than a "missing keys" error.

    Fixes #26470.

    *Chris Carter*

*   Fix adding implicitly rendered template digests to ETags.

    Fixes a case when modifying an implicitly rendered template for a
    controller action using `fresh_when` or `stale?` would not result in a new
    `ETag` value.

    *Javan Makhmali*

*   Make `fixture_file_upload` work in integration tests.

    *Yuji Yaginuma*

*   Add `to_param` to `ActionController::Parameters` deprecations.

    In the future `ActionController::Parameters` are discouraged from being used
    in URLs without explicit whitelisting. Go through `to_h` to use `to_param`.

    *Kir Shatrov*

*   Fix nested multiple roots

    The PR #20940 enabled the use of multiple roots with different constraints
    at the top level but unfortunately didn't work when those roots were inside
    a namespace and also broke the use of root inside a namespace after a top
    level root was defined because the check for the existence of the named route
    used the global :root name and not the namespaced name.

    This is fixed by using the name_for_action method to expand the :root name to
    the full namespaced name. We can pass nil for the second argument as we're not
    dealing with resource definitions so don't need to handle the cases for edit
    and new routes.

    Fixes #26148.

    *Ryo Hashimoto*, *Andrew White*

*   Include the content of the flash in the auto-generated etag. This solves the following problem:

      1. POST /messages
      2. redirect_to messages_url, notice: 'Message was created'
      3. GET /messages/1
      4. GET /messages

      Step 4 would before still include the flash message, even though it's no longer relevant,
      because the etag cache was recorded with the flash in place and didn't change when it was gone.

    *DHH*

*   SSL: Changes redirect behavior for all non-GET and non-HEAD requests
    (like POST/PUT/PATCH etc) to `http://` resources to redirect to `https://`
    with a [307 status code](http://tools.ietf.org/html/rfc7231#section-6.4.7) instead of [301 status code](http://tools.ietf.org/html/rfc7231#section-6.4.2).

    307 status code instructs the HTTP clients to preserve the original
    request method while redirecting. It has been part of HTTP RFC since
    1999 and is implemented/recognized by most (if not all) user agents.

        # Before
        POST http://example.com/articles (i.e. ArticlesContoller#create)
        redirects to
        GET https://example.com/articles (i.e. ArticlesContoller#index)

        # After
        POST http://example.com/articles (i.e. ArticlesContoller#create)
        redirects to
        POST https://example.com/articles (i.e. ArticlesContoller#create)

   *Chirag Singhal*

*   Add `:as` option to `ActionController:TestCase#process` and related methods.

    Specifying `as: mime_type` allows the `CONTENT_TYPE` header to be specified
    in controller tests without manually doing this through `@request.headers['CONTENT_TYPE']`.

    *Everest Stefan Munro-Zeisberger*

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
