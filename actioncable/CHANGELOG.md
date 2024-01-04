*   Add two new assertion methods for ActionCable test cases: `assert_not_has_stream`
    and `assert_not_has_stream_for`. These methods can be used to assert that a
    stream has been stopped, e.g. via `stop_stream` or `stop_stream_for`. They complement
    the already existing `assert_has_stream` and `assert_has_stream_for` methods.

    ```ruby
    assert_not_has_stream "messages"
    assert_not_has_stream_for User.find(42)
    ```

    *Sebastian Pöll*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actioncable/CHANGELOG.md) for previous changes.
