*   `truncate` would return the original string if it was too short to be truncated
    and a frozen string if it were long enough to be truncated. Now truncate will
    consistently return an unfrozen string regardless. This behavior is consistent
    with `gsub` and `strip`.

    Before:

      'foobar'.truncate(5).frozen?
      => true
      'foobar'.truncate(6).frozen?
      => false

    After:

      'foobar'.truncate(5).frozen?
      => false
      'foobar'.truncate(6).frozen?
      => false

    *Jordan Thomas*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activesupport/CHANGELOG.md) for previous changes.
