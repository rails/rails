*   Call `Object#dup` on `default:` values

    Don't share `default:` values across all instances

    ```ruby
    class Model
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :array, default: []
      attribute :hash, default: {}
    end

    a = Model.new
    b = Model.new

    a.array << 1
    a.hash[:a] = 1

    a.array # => [1]
    a.hash # => { a: 1 }

    b.array # => []
    b.hash # => {}
    ```

    *Sean Doyle*

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
