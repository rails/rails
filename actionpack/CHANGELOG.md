*   Store original exception in action_dispatch.exception, not exception cause

    Previously, when an error was raised that had a cause, we would store the cause
    of the error in `request.env["action_dispatch.exception"]`, rather than the
    error itself. That causes a loss of important information - it's not possible
    to get back to the top-level error from the stored exception (since the `cause`
    relationship on errors in one-way).

    After this change, it is the top-level error, rather than its cause, that will
    be stored in `request.env["action_dispatch.exception"]`. Any exception handler
    app can then take responsibilty for inspecting the error's cause, if required.

    Reverses the (undesired) change in behaviour from
    https://github.com/rails/rails/pull/18774

    *Grey Baker*

*   Check `request.path_parameters` encoding at the point they're set

    Check for any non-UTF8 characters in path parameters at the point they're
    set in `env`. Previously they were checked for when used to get a controller
    class, but this meant routes that went directly to a Rack app, or skipped
    controller instantiation for some other reason, had to defend against
    non-UTF8 characters themselves.

    *Grey Baker*

*   Don't raise ActionController::UnknownHttpMethod from ActionDispatch::Static

    Pass `Rack::Request` objects to `ActionDispatch::FileHandler` to avoid it
    raising `ActionController::UnknownHttpMethod`. If an unknown method is
    passed, it should exception higher in the stack instead, once we've had a
    chance to define exception handling behaviour.

    *Grey Baker*

*   Handle `Rack::QueryParser` errors in `ActionDispatch::ExceptionWrapper`

    Updated `ActionDispatch::ExceptionWrapper` to handle the Rack 2.0 namespace
    for `ParameterTypeError` and `InvalidParameterError` errors.

    *Grey Baker*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md) for previous changes.
