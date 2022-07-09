*   Support infinite ranges for `LengthValidator`s `:in`/`:within` options

    ```ruby
    validates_length_of :first_name, in: ..30
    ```

    *fatkodima*

*   Add support for beginless ranges to inclusivity/exclusivity validators:

    ```ruby
    validates_inclusion_of :birth_date, in: -> { (..Date.today) }
    ```

    *Bo Jeanes*

*   Make validators accept lambdas without record argument

    ```ruby
    # Before
    validates_comparison_of :birth_date, less_than_or_equal_to: ->(_record) { Date.today }

    # After
    validates_comparison_of :birth_date, less_than_or_equal_to: -> { Date.today }
    ```

    *fatkodima*

*   Define `deconstruct_keys` in `ActiveModel::AttributeMethods`

*   Fix casting long strings to `Date`, `Time` or `DateTime`

    *fatkodima*

*   Use different cache namespace for proxy calls

    Models can currently have different attribute bodies for the same method
    names, leading to conflicts. Adding a new namespace `:active_model_proxy`
    fixes the issue.

    *Chris Salzberg*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activemodel/CHANGELOG.md) for previous changes.
