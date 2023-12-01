*   Allow the `numericality` validator to accept ranges and arrays returned
    from method calls

    ```ruby
    class MyModel
    validates :numericality, in: { range }

      def range
        qualified_for_2? ? 0..2 : 0..1
      end
    end
    ```

    *Dan Tuls*

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
