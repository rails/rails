*   When a uniqueness validation fails, the `errors.details` hash for the attribute
    now includes an `:existing_id` key, holding the ID of the record that caused
    the conflict.

    ```ruby
    # Before
    errors.details[:name]
    # => [{error: :taken, value: "John Doe"}]

    # After
    errors.details[:name]
    # => [{error: :taken, value: "John Doe", existing_id: 123}]
    ```

    *Bruno Vicenzo*

*   Fix negative scopes for enums to include records with `nil` values.

    *fatkodima*

*   Improve support for SQLite database URIs.

    The `db:create` and `db:drop` tasks now correctly handle SQLite database URIs, and the
    SQLite3Adapter will create the parent directory if it does not exist.

    *Mike Dalessio*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activerecord/CHANGELOG.md) for previous changes.
