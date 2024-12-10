## Rails 7.2.2.1 (December 10, 2024) ##

*   No changes.


## Rails 7.2.2 (October 30, 2024) ##

*   No changes.


## Rails 7.2.1.2 (October 23, 2024) ##

*   No changes.


## Rails 7.2.1.1 (October 15, 2024) ##

*   No changes.


## Rails 7.2.1 (August 22, 2024) ##

*   No changes.


## Rails 7.2.0 (August 09, 2024) ##

*   Bring `ActionCable::Connection::TestCookieJar` in alignment with `ActionDispatch::Cookies::CookieJar` in regards to setting the cookie value.

    Before:

    ```ruby
    cookies[:foo] = { value: "bar" }
    puts cookies[:foo] # => { value: "bar" }
    ```

    After:

    ```ruby
    cookies[:foo] = { value: "bar" }
    puts cookies[:foo] # => "bar"
    ```

    *Justin Ko*

*   Record ping on every Action Cable message.

    Previously only `ping` and `welcome` message types were keeping the connection active.
    Now every Action Cable message updates the `pingedAt` value, preventing the connection
    from being marked as stale.

    *yauhenininjia*

*   Add two new assertion methods for Action Cable test cases: `assert_has_no_stream`
    and `assert_has_no_stream_for`.

    These methods can be used to assert that a stream has been stopped, e.g. via
    `stop_stream` or `stop_stream_for`. They complement the already existing
    `assert_has_stream` and `assert_has_stream_for` methods.

    ```ruby
    assert_has_no_stream "messages"
    assert_has_no_stream_for User.find(42)
    ```

    *Sebastian Pöll*, *Junichi Sato*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actioncable/CHANGELOG.md) for previous changes.
