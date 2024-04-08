*   Record ping on every Action Cable message.

    Previously only `ping` and `welcome` message types were keeping the connection active.
    Now every Action Cable message updates the `pingedAt` value, preventing the connection
    from being marked as stale.

    *yauhenininjia*

*   Add two new assertion methods for Action Cable test cases: `assert_has_no_stream`
    and `assert_has_no_stream_for`. These methods can be used to assert that a
    stream has been stopped, e.g. via `stop_stream` or `stop_stream_for`. They complement
    the already existing `assert_has_stream` and `assert_has_stream_for` methods.

    ```ruby
    assert_has_no_stream "messages"
    assert_has_no_stream_for User.find(42)
    ```

    *Sebastian Pöll*, *Junichi Sato*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actioncable/CHANGELOG.md) for previous changes.
