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
