*   Append link to bad code to backtrace when exception is SyntaxError.

    *Boris Kuznetsov*
    
*   Swapped the parameters of assert_equal in `assert_select` so that the
    proper values were printed correctly 

    Fixes #14422.

    *Vishal Lal*

*   The method `shallow?` returns false if the parent resource is a singleton so
    we need to check if we're not inside a nested scope before copying the :path
    and :as options to their shallow equivalents.

    Fixes #14388.

    *Andrew White*

*   Make logging of CSRF failures optional (but on by default) with the
    `log_warning_on_csrf_failure` configuration setting in
    `ActionController::RequestForgeryProtection`.

    *John Barton*

*   Fix URL generation in controller tests with request-dependent
    `default_url_options` methods.

    *Tony Wooster*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionpack/CHANGELOG.md) for previous changes.
