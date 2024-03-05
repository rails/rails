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

*   Add `skip_on` option to Active Model Validation Options.
    this option allow to skip specific validation in specific context.

      ```ruby
      class MyModel
        include ActiveModel::Validations

        validates :name, presence: true, skip_on: :custom_context
      end

      my_model = MyModel.new
      my_model.valid? # => false
      my_model.valid?(:custom_context) # => true
      ```

    *Ahmed Bin Shamlh*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
