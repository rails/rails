*   Make logging of CSRF failures optional (but on by default) with the
    `log_warning_on_csrf_failure` configuration setting in
    `ActionController::RequestForgeryProtection`.

    *John Barton*

*   Fix URL generation in controller tests with request-dependent
    `default_url_options` methods.

    *Tony Wooster*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionpack/CHANGELOG.md) for previous changes.
