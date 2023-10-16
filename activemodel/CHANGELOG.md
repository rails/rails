*   Add `&block` support for `ActiveModel::API#initialize`

    Supports a block like `ActiveRecord::Base`:

    ```ruby
    person = Person.new { |person| person.name = "Ruby" }
    person.name # => "Ruby"
    ```

    *Sean Doyle*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
