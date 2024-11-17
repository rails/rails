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

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md) for previous changes.
