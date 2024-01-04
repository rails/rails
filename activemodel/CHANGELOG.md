*   Port `ActiveRecord::AttributeMethods::Query` to Active Model. Classes that include
    `ActiveModel::Attributes` will now provide this method. This method behaves
    the same for Active Model as it does for Active Record.

      ```ruby
      class Product
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :archived, :boolean
        attribute :inventory_count, :integer
        attribute :name, :string
      end

      Product.new(archived: true).archived?  # => true
      Product.new(archived: "1").archived?   # => true
      Product.new(archived: false).archived? # => false
      Product.new(archived: "0").archived?   # => false

      Product.new(inventory_count: 1).inventory_count? # => true
      Product.new(inventory_count: 0).inventory_count? # => false

      Product.new(name: "Orange").name?      # => true
      Product.new(name: "").name?            # => false
      ```

    *Sean Doyle*

## Rails 8.1.0.beta1 (September 04, 2025) ##

*   Add `except_on:` option for validation callbacks.

    *Ben Sheldon*

*   Backport `ActiveRecord::Normalization` to `ActiveModel::Attributes::Normalization`

    ```ruby
    class User
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      attribute :email, :string

      normalizes :email, with: -> email { email.strip.downcase }
    end

    user = User.new
    user.email =    " CRUISE-CONTROL@EXAMPLE.COM\n"
    user.email # => "cruise-control@example.com"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
