*   Deprecate addition for `Time` instances with `ActiveSupport::TimeWithZone`.

    Previously adding time instances together such as `10.days.ago + 10.days.ago` produced a nonsensical future date. This behavior is deprecated and will be removed in Rails 8.0.

    *Nick Schwaderer*

*   Support rfc2822 format for Time#to_fs & Date#to_fs.

    *Akshay Birajdar*

*   Optimize load time for `Railtie#initialize_i18n`. Filter `I18n.load_path`s passed to the file watcher to only those
    under `Rails.root`. Previously the watcher would grab all available locales, including those in gems
    which do not require a watcher because they won't change.

    *Nick Schwaderer*

*   Add a `filter` option to `in_order_of` to prioritize certain values in the sorting without filtering the results
    by these values.

    *Igor Depolli*

*   Improve error message when using `assert_difference` or `assert_changes` with a
    proc by printing the proc's source code (MRI only).

    *Richard Böhme*, *Jean Boussier*

*   Add a new configuration value `:zone` for `ActiveSupport.to_time_preserves_timezone` and rename the previous `true` value to `:offset`. The new default value is `:zone`.

    *Jason Kim*, *John Hawthorn*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activesupport/CHANGELOG.md) for previous changes.
