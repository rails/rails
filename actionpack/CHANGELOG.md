*   Unify the behavior of two `tld_length` in
    `actionpack/lib/action_dispatch/middleware/cookies.rb`
    and `actionpack/lib/action_dispatch/http/url.rb`

    The two `tld_length` had different behavior before.
    For example, suppose that we have the domain `sub1.sub2.example.com`.
    When we set the `tld_length` option of cookies to 2:

        cookies[:name] = { value: 'a yummy cookie', domain: :all, tld_length: 2 }

    or set the option of `cookie_store` to the same value:

        MyApp::Application.config.session_store :cookie_store, domain: :all, tld_length: 2

    Then the TLD of cookies will be `example.com`.

    On the other hand, when we set the `tld_length` of `config.action_dispatch` to 2:

        MyApp::Application.configure do
          config.action_dispatch.tld_length = 2
        end

    The TLD of URLs will be `sub2.example.com`.

        ActionDispatch::Http::URL.extract_domain("sub1.sub2.example.com")
        # => "sub2.example.com"

    These different behavior were confused. We had to set the two `tld_length` to
    two different value although which should have the same meaning.

    Now the `tld_length` option of cookies is modified to behave the same way with
    the another. That means if we set the `tld_length` option of cookies to 2, the
    TLD of cookies will also be `sub2.example.com` now.

    So if you had set the `tld_length` option of cookies before, you should
    decrement them by 1.

    *Weihu Chen*

*   Make URL escaping more consistent:

    1. Escape '%' characters in URLs - only unescaped data should be passed to URL helpers
    2. Add an `escape_segment` helper to `Router::Utils` that escapes '/' characters
    3. Use `escape_segment` rather than `escape_fragment` in optimized URL generation
    4. Use `escape_segment` rather than `escape_path` in URL generation

    For point 4 there are two exceptions. Firstly, when a route uses wildcard segments
    (e.g. *foo) then we use `escape_path` as the value may contain '/' characters. This
    means that wildcard routes can't be optimized. Secondly, if a `:controller` segment
    is used in the path then this uses `escape_path` as the controller may be namespaced.

    Fixes #14629, #14636 and #14070.

    *Andrew White*, *Edho Arief*

*   Add alias `ActionDispatch::Http::UploadedFile#to_io` to
    `ActionDispatch::Http::UploadedFile#tempfile`.

    *Tim Linquist*

*   Returns null type format when format is not know and controller is using `any`
    format block.

    Fixes #14462.

    *Rafael Mendonça França*

*   Improve routing error page with fuzzy matching search.

    *Winston*

*   Only make deeply nested routes shallow when parent is shallow.

    Fixes #14684.

    *Andrew White*, *James Coglan*

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
