*   Added new test assertions  `assert_error_on` and `assert_no_error_on` to simplify testing for specific validation errors on models.
    Example usage:
    ```ruby
    assert_error_on user :name, :blank
    assert_no_error user, :name, :blank
    ```

    *Daniela Velasquez*
Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md) for previous changes.
