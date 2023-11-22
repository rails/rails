*   Add a `multiple_of` option to the `numericality` validator.

      ```ruby
      class MyModel
        validates :offset, numericality: { multiple_of: 7 }
      end

      model = MyModel.new

      model.offset = -7
      model.valid? # => true

      model.offset = 0
      model.valid? # => true

      model.offset = 7
      model.valid? # => true

      model.offset = 10
      model.valid? # => false
      ```

    *Joshua Young*

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

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
