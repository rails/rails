*   Numericality validation should skip `:greater_than`, `:greater_than_or_equal_to`, `:less_than`,
    `:less_than_or_equal_to` checks when a proc or a method call return nil instead of throwing
    `ArgumentError: comparison of Integer with nil failed`.

    Example:

    ```
    class ProductFilter
      include ActiveModel::Validations

      validates :min_price, numericality: { allow_nil: true }
      validates :max_price, numericality: { allow_nil: true, greater_than: :min_price }
    end

    ProductFilter.new(max_price: 100).valid? # => true
    ```

    *Dmitry Tsepelev*

*   Raise FrozenError when trying to write attributes that aren't backed by the database on an object that is frozen:

        class Animal
          include ActiveModel::Attributes  
          attribute :age 
        end

        animal = Animal.new
        animal.freeze 
        animal.age = 25 # => FrozenError, "can't modify a frozen Animal"

*   Add *_previously_was attribute methods when dirty tracking. Example:

        pirate.update(catchphrase: "Ahoy!")
        pirate.previous_changes["catchphrase"] # => ["Thar She Blows!", "Ahoy!"]
        pirate.catchphrase_previously_was # => "Thar She Blows!"

    *DHH*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activemodel/CHANGELOG.md) for previous changes.
