*   Yield attributes to block when calling `ActiveModel::Serialization::JSON#from_json`

    ```ruby
    class Person
      include ActiveModel::Serializers::JSON

      attr_accessor :name, :born_on

      def attributes=(hash)
        hash.each do |key, value|
        send("#{key}=", value)
        end
      end
    end

    payload <<~JSON
      { "name": "Alice", "bornOn": "2024-03-08" }
    JSON

    person = Person.new
    person.from_json(payload) { |attributes| attributes.deep_transform_keys!(&:underscore) }
    person.name # => "Alice"
    person.born_on # => "2024-03-08"
    ```

    *Sean Doyle*

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

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
