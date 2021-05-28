*   Previously, `acts_like?` would return true no matter what `acts_like_*` returned,
    however this behavior is now deprecated for non-boolean return values.

    ```ruby
    class RubberDuck
      # Deprecated
      def acts_like_duck; end

      # Should be updated to
      def acts_like_duck
        true
      end
    end
    ```

    The return value of `acts_like_*` will always be used by enabling the configuration:

    ```ruby
    config.active_support.use_acts_like_return_value = true
    ```

    *Hartley McGuire*

*   Add `ActiveSupport::TestCase#stub_const` to stub a constant for the duration of a yield.

    *DHH*

*   Fix `ActiveSupport::EncryptedConfiguration` to be compatible with Psych 4

    *Stephen Sugden*

*   Improve `File.atomic_write` error handling

*   Fix `Class#descendants` and `DescendantsTracker#descendants` compatibility with Ruby 3.1.

    [The native `Class#descendants` was reverted prior to Ruby 3.1 release](https://bugs.ruby-lang.org/issues/14394#note-33),
    but `Class#subclasses` was kept, breaking the feature detection.

    *Jean Boussier*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md) for previous changes.
