*   Fix implicit coercion calculations with scalars and durations

    Previously calculations where the scalar is first would be converted to a duration
    of seconds but this causes issues with dates being converted to times, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 172800 seconds
        date + 2 * 1.day                # => Mon, 22 May 2017 00:00:00 CST +08:00

    Now the `ActiveSupport::Duration::Scalar` calculation methods will try to maintain
    the part structure of the duration where possible, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 2 days
        date + 2 * 1.day                # => Mon, 22 May 2017

    Fixes #29160, #28970.

    *Andrew White*

*   Add support for versioned cache entries. This enables the cache stores to recycle cache keys, greatly saving
    on storage in cases with frequent churn. Works together with the separation of `#cache_key` and `#cache_version`
    in Active Record and its use in Action Pack's fragment caching.

    *DHH*

*   Pass gem name and deprecation horizon to deprecation notifications.

    *Willem van Bergen*

*   Add support for `:offset` and `:zone` to `ActiveSupport::TimeWithZone#change`

    *Andrew White*

*   Add support for `:offset` to `Time#change`

    Fixes #28723.

    *Andrew White*

*   Add `fetch_values` for `HashWithIndifferentAccess`

    The method was originally added to `Hash` in Ruby 2.3.0.

    *Josh Pencheon*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activesupport/CHANGELOG.md) for previous changes.
