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
