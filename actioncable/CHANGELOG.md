*   `ActionCable.server.remote_connections.where(...).disconnect` now sends `disconnect` message
    before closing the connection with the reconnection strategy specified (defaults to `true`).

    *Vladimir Dementyev*

*   Added command callbacks to `ActionCable::Base::Connection`.

    Now you can define `before_command`, `after_command`, and `around_command` to be invoked before, after or around any command received by a client respectively.

    *Vladimir Dementyev*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actioncable/CHANGELOG.md) for previous changes.
