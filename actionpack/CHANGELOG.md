*   `ActionController::Renderer` now uses the same default host (`www.example.com`)
    as `ActionDispatch::Integration::Session`, preventing spurious test failures
    when rendering templates outside of a controller action during integration tests.

    *David Moles*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionpack/CHANGELOG.md) for previous changes.
