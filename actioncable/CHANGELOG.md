*   Permit same-origin connections by default.

    New option `config.action_cable.allow_same_origin_as_host = false`
    to disable.

    *Dávid Halász*, *Matthew Draper*

*   Prevent race where the client could receive and act upon a
    subscription confirmation before the channel's `subscribed` method
    completed.

    Fixes #25381.

    *Vladimir Dementyev*

*   Buffer writes to websocket connections, to avoid blocking threads
    that could be doing more useful things.

    *Matthew Draper*, *Tinco Andringa*

*   Protect against concurrent writes to a websocket connection from
    multiple threads; the underlying OS write is not always threadsafe.

    *Tinco Andringa*

*   Add ActiveSupport::Notifications hook to Broadcaster#broadcast.

    *Matthew Wear*

*   Close hijacked socket when connection is shut down.

    Fixes #25613.

    *Tinco Andringa*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md) for previous changes.
