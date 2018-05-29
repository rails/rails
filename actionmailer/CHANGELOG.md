## Rails 6.0.0.alpha (Unreleased) ##

*   Add `Base.unregister_observer`, `Base.unregister_observers`,
    `Base.unregister_interceptor`, `Base.unregister_interceptors`,
    `Base.unregister_preview_interceptor` and `Base.unregister_preview_interceptors`.
    This makes it possible to dynamically add and remove email observers and
    interceptors at runtime in the same way they're registered.

    *Kota Miyake*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionmailer/CHANGELOG.md) for previous changes.
