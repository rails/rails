*   Fix and extend `Enumerable#many?`.

    ```ruby
    # Before
    [nil, false].none?  # => true
    [nil, false].many?  # => true

    # After
    [nil, false].many?  # => false

    # Accept a pattern just like #any?, #none? and #all?
    [1, :b, 3.0].many?(Integer)  # => false
    possible_emails.many?(EMAIL_REGEXP)
    ```

    *Gert Goet*

*   Change default serialization format of `MessageEncryptor` from `Marshal` to `JSON` for Rails 7.1.

    Existing apps are provided with an upgrade path to migrate to `JSON` as described in `guides/source/upgrading_ruby_on_rails.md`

    *Zack Deveau* and *Martin Gingras*

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
