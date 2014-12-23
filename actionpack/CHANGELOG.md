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
