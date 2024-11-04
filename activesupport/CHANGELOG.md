*   Better error message for `Enumerable#sole`.

    Include the number of items in the message if there are more than one.

    Before:

    ```ruby
    [1, 2].sole
    # => raises Enumerable::SoleItemExpectedError: multiple items found
    ```

    After:

    ```ruby
    [1, 2].sole
    # => raises Enumerable::SoleItemExpectedError: 2 items found
    ```

    *Dani Acherkan*
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
