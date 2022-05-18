*   Deprecated `:pool_size` and `:pool_timeout` options for configuring connection pooling in cache stores.

    Use `pool: true` to enable pooling with default settings:

    ```ruby
    config.cache_store = :redis_cache_store, pool: true
    ```

    Or pass individual options via `:pool` option:

    ```ruby
    config.cache_store = :redis_cache_store, pool: { size: 10, timeout: 2 }
    ```

    *fatkodima*

*   Allow #increment and #decrement methods of `ActiveSupport::Cache::Store`
    subclasses to set new values.

    Previously incrementing or decrementing an unset key would fail and return
    nil. A default will now be assumed and the key will be created.

    *Andrej Blagojević*, *Eugene Kenny*

*   Add `skip_nil:` support to `RedisCacheStore`

    *Joey Paris*

*   `ActiveSupport::Cache::MemoryStore#write(name, val, unless_exist:true)` now
    correctly writes expired keys.

    *Alan Savage*

*   `ActiveSupport::ErrorReporter` now accepts and forward a `source:` parameter.

    This allow libraries to signal the origin of the errors, and reporters
    to easily ignore some sources.

    *Jean Boussier*

*   Fix and add protections for XSS in `ActionView::Helpers` and `ERB::Util`.

    Add the method `ERB::Util.xml_name_escape` to escape dangerous characters
    in names of tags and names of attributes, following the specification of XML.

    *Álvaro Martín Fraguas*

*   Respect `ActiveSupport::Logger.new`'s `:formatter` keyword argument

    The stdlib `Logger::new` allows passing a `:formatter` keyword argument to
    set the logger's formatter. Previously `ActiveSupport::Logger.new` ignored
    that argument by always setting the formatter to an instance of
    `ActiveSupport::Logger::SimpleFormatter`.

    *Steven Harman*

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
