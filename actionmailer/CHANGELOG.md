*   Ensure mail gem is eager autoloaded when eager load is true to prevent thread deadlocks.

    *Samuel Cochran*

*   Perform email jobs in `assert_emails`.

    *Gannon McGibbon*

*   Add `Base.unregister_observer`, `Base.unregister_observers`,
    `Base.unregister_interceptor`, `Base.unregister_interceptors`,
    `Base.unregister_preview_interceptor` and `Base.unregister_preview_interceptors`.
    This makes it possible to dynamically add and remove email observers and
    interceptors at runtime in the same way they're registered.

    *Claudio Ortolina*, *Kota Miyake*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionmailer/CHANGELOG.md) for previous changes.
