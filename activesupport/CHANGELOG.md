*   Allow some tests to run serially while using parallel testing

    `ActiveSupport::TestCase` runs serially when [Minitest::Test.test_order](https://github.com/seattlerb/minitest/blob/master/lib/minitest/test.rb#L83) is not `:parallel` to respect default Minitest behaviour.

    *Louis Boudreau*
    

*   Deprecate preserving the pre-Ruby 2.4 behavior of `to_time`

    With Ruby 2.4+ the default for +to_time+ changed from converting to the
    local system time to preserving the offset of the receiver. At the time Rails
    supported older versions of Ruby so a compatibility layer was added to assist
    in the migration process. From Rails 5.0 new applications have defaulted to 
    the Ruby 2.4+ behavior and since Rails 7.0 now only supports Ruby 2.7+
    this compatibility layer can be safely removed.
    
    To minimize any noise generated the deprecation warning only appears when the
    setting is configured to `false` as that is the only scenario where the
    removal of the compatibility layer has any effect.
    
    *Andrew White*

*   `Pathname.blank?` only returns true for `Pathname.new("")`

    Previously it would end up calling `Pathname#empty?` which returned true
    if the path existed and was an empty directory or file.

    That behavior was unlikely to be expected.

    *Jean Boussier*

*   Deprecate `Notification::Event`'s `#children` and `#parent_of?`

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
