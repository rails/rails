*   Make validators accept lambdas without record argument

    ```ruby
    # Before
    validates_comparison_of :birth_date, less_than_or_equal_to: ->(_record) { Date.today }

    # After
    validates_comparison_of :birth_date, less_than_or_equal_to: -> { Date.today }
    ```

    *fatkodima*

*   Define `deconstruct_keys` in `ActiveModel::AttributeMethods`

    This provides the Ruby 2.7+ pattern matching interface for hash patterns,
    which allows the user to pattern match against anything that includes the
    `ActiveModel::AttributeMethods` module (e.g., `ActiveRecord::Base`). As an
    example, you can now:

    ```ruby
    class Person < ActiveRecord::Base
    end

    person = Person.new(name: "Mary")
    person => { name: }
    name # => "Mary"
    ```

    *Kevin Newton*

*   Fix casting long strings to `Date`, `Time` or `DateTime`

    *fatkodima*

*   Use different cache namespace for proxy calls

    Models can currently have different attribute bodies for the same method
    names, leading to conflicts. Adding a new namespace `:active_model_proxy`
    fixes the issue.

    *Chris Salzberg*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activemodel/CHANGELOG.md) for previous changes.
