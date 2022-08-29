*   `default` option of `thread_mattr_accessor` now applies through inheritance and
    also across new threads.

    Previously, the `default` value provided was set only at the moment of defining
    the attribute writer, which would cause the attribute to be uninitialized in
    descendants and in other threads.

    Fixes #43312.

    *Thierry Deo*

*   Redis cache store is now compatible with redis-rb 5.0.

    *Jean Boussier*

*   Add `skip_nil:` support to `ActiveSupport::Cache::Store#fetch_multi`.

    *Daniel Alfaro*

*   Add `quarter` method to date/time

    *Matt Swanson*

*   Fix `NoMethodError` on custom `ActiveSupport::Deprecation` behavior.

    `ActiveSupport::Deprecation.behavior=` was supposed to accept any object
    that responds to `call`, but in fact its internal implementation assumed that
    this object could respond to `arity`, so it was restricted to only `Proc` objects.

    This change removes this `arity` restriction of custom behaviors.

    *Ryo Nakamura*

*   Support `:url_safe` option for `MessageEncryptor`.

    The `MessageEncryptor` constructor now accepts a `:url_safe` option, similar
    to the `MessageVerifier` constructor.  When enabled, this option ensures
    that messages use a URL-safe encoding.

    *Jonathan Hefner*

*   Add `url_safe` option to `ActiveSupport::MessageVerifier` initializer

    `ActiveSupport::MessageVerifier.new` now takes optional `url_safe` argument.
    It can generate URL-safe strings by passing `url_safe: true`.

    ```ruby
    verifier = ActiveSupport::MessageVerifier.new(url_safe: true)
    message = verifier.generate(data) # => URL-safe string
    ```

    This option is `false` by default to be backwards compatible.

    *Shouichi Kamiya*

*   Enable connection pooling by default for `MemCacheStore` and `RedisCacheStore`.

    If you want to disable connection pooling, set `:pool` option to `false` when configuring the cache store:

    ```ruby
    config.cache_store = :mem_cache_store, "cache.example.com", pool: false
    ```

    *fatkodima*

*   Add `force:` support to `ActiveSupport::Cache::Store#fetch_multi`.

    *fatkodima*

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

    *John Hawthorn*

*   Change default serialization format of `MessageEncryptor` from `Marshal` to `JSON` for Rails 7.1.

    Existing apps are provided with an upgrade path to migrate to `JSON` as described in `guides/source/upgrading_ruby_on_rails.md`

    *Zack Deveau* and *Martin Gingras*

*   Add `ActiveSupport::TestCase#stub_const` to stub a constant for the duration of a yield.

    *DHH*

*   Fix `ActiveSupport::EncryptedConfiguration` to be compatible with Psych 4

    *Stephen Sugden*

*   Improve `File.atomic_write` error handling

    *Daniel Pepper*

*   Fix `Class#descendants` and `DescendantsTracker#descendants` compatibility with Ruby 3.1.

    [The native `Class#descendants` was reverted prior to Ruby 3.1 release](https://bugs.ruby-lang.org/issues/14394#note-33),
    but `Class#subclasses` was kept, breaking the feature detection.

    *Jean Boussier*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activesupport/CHANGELOG.md) for previous changes.
