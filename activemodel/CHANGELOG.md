*   Fix a bug where type casting of string to `Time` and `DateTime` doesn't
    calculate minus minute value in TZ offset correctly.

    *Akira Matsuda*

*   Port the `type_for_attribute` method to Active Model. Classes that include
    `ActiveModel::Attributes` will now provide this method. This method behaves
    the same for Active Model as it does for Active Record.

      ```ruby
      class MyModel
        include ActiveModel::Attributes

        attribute :my_attribute, :integer
      end

      MyModel.type_for_attribute(:my_attribute) # => #<ActiveModel::Type::Integer ...>
      ```

    *Jonathan Hefner*

*   Add the `value_format` option for validations such as `numericality`,
    `length`, and `comparison`.
    This option enables formatting the value passed to `%{count}` in i18n
    messages.

    e.g. In the following code, it will be generated messages is
    _"must be equal to 1,000"_.

    ```ruby
    class MyModel < ApplicationRecord
      validates :my_attribute, numericality: {
        equal_to: 1_000,
        value_format: -> (value) { value.to_fs(:delimited) }
      }
    end
    ```

    *Ryoya Kato*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
