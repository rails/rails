*   Redis pub/sub adapter now automatically reconnects when Redis connection is lost.

    *Vladimir Dementyev*

*   The `connected()` callback can now take a `{reconnected}` parameter to differentiate
    connections from reconnections.

    ```js
    import consumer from "./consumer"

    consumer.subscriptions.create("ExampleChannel", {
      connected({reconnected}) {
        if (reconnected) {
          ...
        } else {
          ...
        }
      }
    })
    ```

    *Mansa Keïta*

*   The Redis adapter is now compatible with redis-rb 5.0

    Compatibility with redis-rb 3.x was dropped.

    *Jean Boussier*

*   The Action Cable server is now mounted with `anchor: true`.

    This means that routes that also start with `/cable` will no longer clash with Action Cable.

    *Alex Ghiculescu*

*   `ActionCable.server.remote_connections.where(...).disconnect` now sends `disconnect` message
    before closing the connection with the reconnection strategy specified (defaults to `true`).

    *Vladimir Dementyev*

*   Added command callbacks to `ActionCable::Connection::Base`.

    Now you can define `before_command`, `after_command`, and `around_command` to be invoked before, after or around any command received by a client respectively.

    *Vladimir Dementyev*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actioncable/CHANGELOG.md) for previous changes.
