*   Fix `RangeError` in `Range#===` and `Range#include?` for endless and beginless ranges

    ```ruby
    (1..) === (2..)
    => true
    (2..) === (1..)
    => false
    (..1) === (..2)
    => false
    (..2) === (..1)
    => true
    ```

    *Alex Mooney*

*   `ActiveSupport::ErrorReporter#report` now assigns a backtrace to unraised exceptions.

    Previously reporting an un-raised exception would result in an error report without
    a backtrace. Now it automatically generates one.

    *Jean Boussier*

*   Add `escape_html_entities` option to `ActiveSupport::JSON.encode`.

    This allows for overriding the global configuration found at
    `ActiveSupport.escape_html_entities_in_json` for specific calls to `to_json`.

    This should be usable from controllers in the following manner:
    ```ruby
    class MyController < ApplicationController
      def index
        render json: { hello: "world" }, escape_html_entities: false
      end
    end
    ```

    *Nigel Baillie*

*   Raise when using key which can't respond to `#to_sym` in `EncryptedConfiguration`.

    As is the case when trying to use an Integer or Float as a key, which is unsupported.

    *zzak*

*   Deprecate addition and since between two `Time` and `ActiveSupport::TimeWithZone`.

    Previously adding time instances together such as `10.days.ago + 10.days.ago` or `10.days.ago.since(10.days.ago)` produced a nonsensical future date. This behavior is deprecated and will be removed in Rails 8.1.

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

*   Align instrumentation `payload[:key]` in ActiveSupport::Cache to follow the same pattern, with namespaced and normalized keys.

    *Frederik Erbs Spang Thomsen*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activesupport/CHANGELOG.md) for previous changes.
