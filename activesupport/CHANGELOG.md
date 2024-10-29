*   Add `after_or_equal?` and `before_or_equal?` methods to `Date`, `DateTime`, `Time`, and `TimeWithZone`.

    These methods provide a more readable alternative to using `>=` and `<=` when comparing dates and times.

    ```ruby
    time1.after_or_equal?(time2)  # equivalent to time1 >= time2
    time1.before_or_equal?(time2) # equivalent to time1 <= time2
    ```

    *martinfsn*

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

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md) for previous changes.
