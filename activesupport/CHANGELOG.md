*   Change execution wrapping to report all exceptions, including `Exception`.

    If a more serious error like `SystemStackError` or `NoMemoryError` happens,
    the error reporter should be able to report these kinds of exceptions.

    *Gannon McGibbon*

*   `ActiveSupport::Testing::Parallelization.before_fork_hook` allows declaration of callbacks that
    are invoked immediately before forking test workers.

    *Mike Dalessio*

*   Allow the `#freeze_time` testing helper to accept a date or time argument.

    ```ruby
    Time.current # => Sun, 09 Jul 2024 15:34:49 EST -05:00
    freeze_time Time.current + 1.day
    sleep 1
    Time.current # => Mon, 10 Jul 2024 15:34:49 EST -05:00
    ```

    *Joshua Young*

*   `ActiveSupport::JSON` now accepts options

    It is now possible to pass options to `ActiveSupport::JSON`:
    ```ruby
    ActiveSupport::JSON.decode('{"key": "value"}', symbolize_names: true) # => { key: "value" }
    ```

    *matthaigh27*

*   `ActiveSupport::Testing::NotificationAssertions`'s `assert_notification` now matches against payload subsets by default.

    Previously the following assertion would fail due to excess key vals in the notification payload. Now with payload subset matching, it will pass.

    ```ruby
    assert_notification("post.submitted", title: "Cool Post") do
      ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: "Cool Body")
    end
    ```

    Additionally, you can now persist a matched notification for more customized assertions.

    ```ruby
    notification = assert_notification("post.submitted", title: "Cool Post") do
      ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: Body.new("Cool Body"))
    end

    assert_instance_of(Body, notification.payload[:body])
    ```

    *Nicholas La Roux*

*   Deprecate `String#mb_chars` and `ActiveSupport::Multibyte::Chars`.

    These APIs are a relic of the Ruby 1.8 days when Ruby strings weren't encoding
    aware. There is no legitimate reasons to need these APIs today.

    *Jean Boussier*

*   Deprecate `ActiveSupport::Configurable`

    *Sean Doyle*

*   `nil.to_query("key")` now returns `key`.

    Previously it would return `key=`, preventing round tripping with `Rack::Utils.parse_nested_query`.

    *Erol Fornoles*

*   Avoid wrapping redis in a `ConnectionPool` when using `ActiveSupport::Cache::RedisCacheStore` if the `:redis`
    option is already a `ConnectionPool`.

    *Joshua Young*

*   Alter `ERB::Util.tokenize` to return :PLAIN token with full input string when string doesn't contain ERB tags.

    *Martin Emde*

*   Fix a bug in `ERB::Util.tokenize` that causes incorrect tokenization when ERB tags are preceeded by multibyte characters.

    *Martin Emde*

*   Add `ActiveSupport::Testing::NotificationAssertions` module to help with testing `ActiveSupport::Notifications`.

    *Nicholas La Roux*, *Yishu See*, *Sean Doyle*

*   `ActiveSupport::CurrentAttributes#attributes` now will return a new hash object on each call.

    Previously, the same hash object was returned each time that method was called.

    *fatkodima*

*   `ActiveSupport::JSON.encode` supports CIDR notation.

    Previously:

    ```ruby
    ActiveSupport::JSON.encode(IPAddr.new("172.16.0.0/24")) # => "\"172.16.0.0\""
    ```

    After this change:

    ```ruby
    ActiveSupport::JSON.encode(IPAddr.new("172.16.0.0/24")) # => "\"172.16.0.0/24\""
    ```

    *Taketo Takashima*

*   Make `ActiveSupport::FileUpdateChecker` faster when checking many file-extensions.

    *Jonathan del Strother*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md) for previous changes.
