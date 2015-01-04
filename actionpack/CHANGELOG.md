*   Remove `respond_to`/`respond_with` placeholder methods, this functionality
    has been extracted to the `responders` gem.

    *Carlos Antonio da Silva*

*   Remove deprecated assertion files.

    *Rafael Mendonça França*

*   Remove deprecated usage of string keys in URL helpers.

    *Rafael Mendonça França*

*   Remove deprecated `only_path` option on `*_path` helpers.

    *Rafael Mendonça França*

*   Remove deprecated `NamedRouteCollection#helpers`.

    *Rafael Mendonça França*

*   Remove deprecated support to define routes with `:to` option that doesn't contain `#`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Response#to_ary`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Request#deep_munge`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Http::Parameters#symbolized_path_parameters`.

    *Rafael Mendonça França*

*   Remove deprecated option `use_route` in controller tests.

    *Rafael Mendonça França*

*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additonal
    payload data is not available.

    See:
    * #14903
    * https://github.com/roidrage/lograge/issues/37

    *Dieter Komendera*, *Margus Pärt*

*   Correctly rely on the response's status code to handle calls to `head`.

    *Robin Dupret*

*   Using `head` method returns empty response_body instead
    of returning a single space " ".

    The old behavior was added as a workaround for a bug in an early
    version of Safari, where the HTTP headers are not returned correctly
    if the response body has a 0-length. This is been fixed since and
    the workaround is no longer necessary.

    Fixes #18253.

    *Prathamesh Sonpatki*

*   Fix how polymorphic routes works with objects that implement `to_model`.

    *Travis Grathwell*

*   Stop converting empty arrays in `params` to `nil`

    This behaviour was introduced in response to CVE-2012-2660, CVE-2012-2694
    and CVE-2013-0155

    ActiveRecord now issues a safe query when passing an empty array into
    a where clause, so there is no longer a need to defend against this type
    of input (any nils are still stripped from the array).

    *Chris Sinjakli*

*   Fixed usage of optional scopes in url helpers.

    *Alex Robbin*

*   Fixed handling of positional url helper arguments when `format: false`.

    Fixes #17819.

    *Andrew White*, *Tatiana Soukiassian*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionpack/CHANGELOG.md) for previous changes.
