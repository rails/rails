*   Port the `BeforeTypeCast` module to Active Model. Classes that include
    `ActiveModel::Attributes` will now automatically define methods such as
    `*_before_type_cast`, `*_for_database`, etc. These methods behave the same
    for Active Model as they do for Active Record.

      ```ruby
      class MyModel
        include ActiveModel::Attributes

        attribute :my_attribute, :integer
      end

      m = MyModel.new
      m.my_attribute = "123"
      m.my_attribute                                   # => 123
      m.my_attribute_before_type_cast                  # => "123"
      m.read_attribute_before_type_cast(:my_attribute) # => "123"
      ```

    *Jonathan Hefner*

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
