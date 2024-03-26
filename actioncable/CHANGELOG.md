*   Add ability to detect a half-open connection

    ActionCable doesn't have a mechanism to detect if its connection is
    half-open (if there isn't a client listening on the other end).

    A half-open connection can linger around for up to half an hour using
    up system resources.

    This patch adds a new revision of the protocol - actioncable-v1.1-json -
    that instructs the client to respond to the server's heartbeat PING
    messages with a PONG message. If a PONG message isn't received by the
    server within two heartbeats the connections is assumed to be half-open
    and is closed.

    *Stanko Krtalić Rusendić*

*   Add two new assertion methods for ActionCable test cases: `assert_has_no_stream`
    and `assert_has_no_stream_for`. These methods can be used to assert that a
    stream has been stopped, e.g. via `stop_stream` or `stop_stream_for`. They complement
    the already existing `assert_has_stream` and `assert_has_stream_for` methods.

    ```ruby
    assert_has_no_stream "messages"
    assert_has_no_stream_for User.find(42)
    ```

    *Sebastian Pöll*, *Junichi Sato*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actioncable/CHANGELOG.md) for previous changes.
