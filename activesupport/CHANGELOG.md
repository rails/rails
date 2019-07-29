*   Add `compact_blank` for those times when you want to remove #blank? values from
    an Enumerable (also `compact_blank!` on Hash, Array, ActionController::Parameters)

    *Dana Sherson*

*   Make ActiveSupport::Logger Fiber-safe. Fixes #36752.

    Use `Fiber.current.__id__` in `ActiveSupport::Logger#local_level=` in order
    to make log level local to Ruby Fibers in addition to Threads.

    Example:

        logger = ActiveSupport::Logger.new(STDOUT)
        logger.level = 1
        p "Main is debug? #{logger.debug?}"

        Fiber.new {
          logger.local_level = 0
          p "Thread is debug? #{logger.debug?}"
        }.resume

        p "Main is debug? #{logger.debug?}"

    Before:

        Main is debug? false
        Thread is debug? true
        Main is debug? true

    After:

        Main is debug? false
        Thread is debug? true
        Main is debug? false

    *Alexander Varnin*

*   Allow the `on_rotation` proc used when decrypting/verifying a message to be
    passed at the constructor level.

    Before:

        crypt = ActiveSupport::MessageEncryptor.new('long_secret')
        crypt.decrypt_and_verify(encrypted_message, on_rotation: proc { ... })
        crypt.decrypt_and_verify(another_encrypted_message, on_rotation: proc { ... })

    After:

        crypt = ActiveSupport::MessageEncryptor.new('long_secret', on_rotation: proc { ... })
        crypt.decrypt_and_verify(encrypted_message)
        crypt.decrypt_and_verify(another_encrypted_message)

    *Edouard Chin*

*   `delegate_missing_to` would raise a `DelegationError` if the object
    delegated to was `nil`. Now the `allow_nil` option has been added to enable
    the user to specify they want `nil` returned in this case.

    *Matthew Tanous*

*   `truncate` would return the original string if it was too short to be truncated
    and a frozen string if it were long enough to be truncated. Now truncate will
    consistently return an unfrozen string regardless. This behavior is consistent
    with `gsub` and `strip`.

    Before:

        'foobar'.truncate(5).frozen?
        # => true
        'foobar'.truncate(6).frozen?
        # => false

    After:

        'foobar'.truncate(5).frozen?
        # => false
        'foobar'.truncate(6).frozen?
        # => false

    *Jordan Thomas*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activesupport/CHANGELOG.md) for previous changes.
