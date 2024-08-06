## Rails 7.2.0.rc1 (August 06, 2024) ##

*   No changes.


## Rails 7.2.0.beta3 (July 11, 2024) ##

*   No changes.


## Rails 7.2.0.beta2 (June 04, 2024) ##

*   No changes.


## Rails 7.2.0.beta1 (May 29, 2024) ##

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
