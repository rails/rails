*   Handle `Rack::QueryParser` errors in `ActionDispatch::ExceptionWrapper`

    Updated `ActionDispatch::ExceptionWrapper` to handle the Rack 2.0 namespace
    for `ParameterTypeError` and `InvalidParameterError` errors.

    *Grey Baker*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md) for previous changes.
