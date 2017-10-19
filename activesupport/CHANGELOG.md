*   Remove deprecated `:if` and `:unless` string filter for callbacks.

    *Rafael Mendonça França*

*   `Hash#slice` now falls back to Ruby 2.5+'s built-in definition if defined.

    *Akira Matsuda*

*   Deprecate `secrets.secret_token`.

    The architecture for secrets had a big upgrade between Rails 3 and Rails 4,
    when the default changed from using `secret_token` to `secret_key_base`.

    `secret_token` has been soft deprecated in documentation for four years
    but is still in place to support apps created before Rails 4.
    Deprecation warnings have been added to help developers upgrade their
    applications to `secret_key_base`.

    *claudiob*, *Kasper Timm Hansen*

*   Return an instance of `HashWithIndifferentAccess` from `HashWithIndifferentAccess#transform_keys`.

    *Yuji Yaginuma*

*   Add key rotation support to `MessageEncryptor` and `MessageVerifier`

    This change introduces a `rotate` method to both the `MessageEncryptor` and
    `MessageVerifier` classes. This method accepts the same arguments and
    options as the given classes' constructor. The `encrypt_and_verify` method
    for `MessageEncryptor` and the `verified` method for `MessageVerifier` also
    accept an optional keyword argument `:on_rotation` block which is called
    when a rotated instance is used to decrypt or verify the message.

    *Michael J Coyne*

*   Deprecate `Module#reachable?` method.

    *bogdanvlviv*

*   Add `config/credentials.yml.enc` to store production app secrets.

    Allows saving any authentication credentials for third party services
    directly in repo encrypted with `config/master.key` or `ENV["RAILS_MASTER_KEY"]`.

    This will eventually replace `Rails.application.secrets` and the encrypted
    secrets introduced in Rails 5.1.

    *DHH*, *Kasper Timm Hansen*

*   Add `ActiveSupport::EncryptedFile` and `ActiveSupport::EncryptedConfiguration`.

    Allows for stashing encrypted files or configuration directly in repo by
    encrypting it with a key.

    Backs the new credentials setup above, but can also be used independently.

    *DHH*, *Kasper Timm Hansen*

*   `Module#delegate_missing_to` now raises `DelegationError` if target is nil,
    similar to `Module#delegate`.

    *Anton Khamets*

*   Update `String#camelize` to provide feedback when wrong option is passed

    `String#camelize` was returning nil without any feedback when an
    invalid option was passed as a parameter.

    Previously:

        'one_two'.camelize(true)
        # => nil

    Now:

        'one_two'.camelize(true)
        # => ArgumentError: Invalid option, use either :upper or :lower.

    *Ricardo Díaz*

*   Fix modulo operations involving durations

    Rails 5.1 introduced `ActiveSupport::Duration::Scalar` as a wrapper
    around numeric values as a way of ensuring a duration was the outcome of
    an expression. However, the implementation was missing support for modulo
    operations. This support has now been added and should result in a duration
    being returned from expressions involving modulo operations.

    Prior to Rails 5.1:

        5.minutes % 2.minutes
        # => 60

    Now:

        5.minutes % 2.minutes
        # => 1 minute

    Fixes #29603 and #29743.

    *Sayan Chakraborty*, *Andrew White*

*   Fix division where a duration is the denominator

    PR #29163 introduced a change in behavior when a duration was the denominator
    in a calculation - this was incorrect as dividing by a duration should always
    return a `Numeric`. The behavior of previous versions of Rails has been restored.

    Fixes #29592.

    *Andrew White*

*   Add purpose and expiry support to `ActiveSupport::MessageVerifier` &
   `ActiveSupport::MessageEncryptor`.

    For instance, to ensure a message is only usable for one intended purpose:

        token = @verifier.generate("x", purpose: :shipping)

        @verifier.verified(token, purpose: :shipping) # => "x"
        @verifier.verified(token)                     # => nil

    Or make it expire after a set time:

        @verifier.generate("x", expires_in: 1.month)
        @verifier.generate("y", expires_at: Time.now.end_of_year)

    Showcased with `ActiveSupport::MessageVerifier`, but works the same for
    `ActiveSupport::MessageEncryptor`'s `encrypt_and_sign` and `decrypt_and_verify`.

    Pull requests: #29599, #29854

    *Assain Jaleel*

*   Make the order of `Hash#reverse_merge!` consistent with `HashWithIndifferentAccess`.

    *Erol Fornoles*

*   Add `freeze_time` helper which freezes time to `Time.now` in tests.

    *Prathamesh Sonpatki*

*   Default `ActiveSupport::MessageEncryptor` to use AES 256 GCM encryption.

    On for new Rails 5.2 apps. Upgrading apps can find the config as a new
    framework default.

    *Assain Jaleel*

*   Cache: `write_multi`

        Rails.cache.write_multi foo: 'bar', baz: 'qux'

    Plus faster fetch_multi with stores that implement `write_multi_entries`.
    Keys that aren't found may be written to the cache store in one shot
    instead of separate writes.

    The default implementation simply calls `write_entry` for each entry.
    Stores may override if they're capable of one-shot bulk writes, like
    Redis `MSET`.

    *Jeremy Daer*

*   Add default option to module and class attribute accessors.

        mattr_accessor :settings, default: {}

    Works for `mattr_reader`, `mattr_writer`, `cattr_accessor`, `cattr_reader`,
    and `cattr_writer` as well.

    *Genadi Samokovarov*

*   Add `Date#prev_occurring` and `Date#next_occurring` to return specified next/previous occurring day of week.

    *Shota Iguchi*

*   Add default option to `class_attribute`.

    Before:

        class_attribute :settings
        self.settings = {}

    Now:

        class_attribute :settings, default: {}

    *DHH*

*   `#singularize` and `#pluralize` now respect uncountables for the specified locale.

    *Eilis Hamilton*

*   Add `ActiveSupport::CurrentAttributes` to provide a thread-isolated attributes singleton.
    Primary use case is keeping all the per-request attributes easily available to the whole system.

    *DHH*

*   Fix implicit coercion calculations with scalars and durations

    Previously, calculations where the scalar is first would be converted to a duration
    of seconds, but this causes issues with dates being converted to times, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 172800 seconds
        date + 2 * 1.day                # => Mon, 22 May 2017 00:00:00 CST +08:00

    Now, the `ActiveSupport::Duration::Scalar` calculation methods will try to maintain
    the part structure of the duration where possible, e.g:

        Time.zone = "Beijing"           # => Asia/Shanghai
        date = Date.civil(2017, 5, 20)  # => Mon, 20 May 2017
        2 * 1.day                       # => 2 days
        date + 2 * 1.day                # => Mon, 22 May 2017

    Fixes #29160, #28970.

    *Andrew White*

*   Add support for versioned cache entries. This enables the cache stores to recycle cache keys, greatly saving
    on storage in cases with frequent churn. Works together with the separation of `#cache_key` and `#cache_version`
    in Active Record and its use in Action Pack's fragment caching.

    *DHH*

*   Pass gem name and deprecation horizon to deprecation notifications.

    *Willem van Bergen*

*   Add support for `:offset` and `:zone` to `ActiveSupport::TimeWithZone#change`

    *Andrew White*

*   Add support for `:offset` to `Time#change`

    Fixes #28723.

    *Andrew White*

*   Add `fetch_values` for `HashWithIndifferentAccess`

    The method was originally added to `Hash` in Ruby 2.3.0.

    *Josh Pencheon*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activesupport/CHANGELOG.md) for previous changes.
