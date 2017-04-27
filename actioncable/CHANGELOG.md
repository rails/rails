## Rails 5.1.0 (April 27, 2017) ##

*   ActionCable socket errors are now logged to the console

    Previously any socket errors were ignored and this made it hard to diagnose socket issues (e.g. as discussed in #28362).

    *Edward Poot*

*   Redis subscription adapters now support `channel_prefix` option in `cable.yml`

    Avoids channel name collisions when multiple apps use the same Redis server.

    *Chad Ingram*

*   Permit same-origin connections by default.

    Added new option `config.action_cable.allow_same_origin_as_host = false`
    to disable this behaviour.

    *Dávid Halász*, *Matthew Draper*

*   Prevent race where the client could receive and act upon a
    subscription confirmation before the channel's `subscribed` method
    completed.

    Fixes #25381.

    *Vladimir Dementyev*

*   Buffer now writes to WebSocket connections, to avoid blocking threads
    that could be doing more useful things.

    *Matthew Draper*, *Tinco Andringa*

*   Protect against concurrent writes to a WebSocket connection from
    multiple threads; the underlying OS write is not always threadsafe.

    *Tinco Andringa*

*   Add `ActiveSupport::Notifications` hook to `Broadcaster#broadcast`.

    *Matthew Wear*

*   Close hijacked socket when connection is shut down.

    Fixes #25613.

    *Tinco Andringa*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md) for previous changes.
