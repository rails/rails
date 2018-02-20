## Rails 6.0.0.alpha (Unreleased) ##

*   Return all mappings for a timezone identifier in `country_zones`

    Some timezones like `Europe/London` have multiple mappings in
    `ActiveSupport::TimeZone::MAPPING` so return all of them instead
    of the first one found by using `Hash#value`. e.g:

        # Before
        ActiveSupport::TimeZone.country_zones("GB") # => ["Edinburgh"]

        # After
        ActiveSupport::TimeZone.country_zones("GB") # => ["Edinburgh", "London"]

    Fixes #31668.

    *Andrew White*

*   `String#truncate_bytes` to truncate a string to a maximum bytesize without
    breaking multibyte characters or grapheme clusters like 👩‍👩‍👦‍👦.

    *Jeremy Daer*

*   `String#strip_heredoc` preserves frozenness.

        "foo".freeze.strip_heredoc.frozen?  # => true

    Fixes that frozen string literals would inadvertently become unfrozen:

        # frozen_string_literal: true

        foo = <<-MSG.strip_heredoc
          la la la
        MSG

        foo.frozen?  # => false !??

    *Jeremy Daer*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*

*   Adds parallel testing to Rails

    Parallelize your test suite with forked processes or threads.

    *Eileen M. Uchitelle*, *Aaron Patterson*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activesupport/CHANGELOG.md) for previous changes.
