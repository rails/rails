*   Add a `filter` option to `in_order_of` to prioritize certain values in the sorting without filtering the results
    by these values.

    *Igor Depolli*

*   Improve error message when using `assert_difference` or `assert_changes` with a
    proc by printing the proc's source code (MRI only).

    *Richard Böhme*, *Jean Boussier*

*   Add a new configuration value `:zone` for `ActiveSupport.to_time_preserves_timezone` and rename the previous `true` value to `:offset`. The new default value is `:zone`.

    *Jason Kim*, *John Hawthorn*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activesupport/CHANGELOG.md) for previous changes.
