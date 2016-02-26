## Rails 4.1.14.2 (February 26, 2016) ##

*   No changes.


## Rails 4.1.14.1 (January 25, 2015) ##

*   No changes.


## Rails 4.1.14 (November 12, 2015) ##

*   No changes.


## Rails 4.1.13 (August 24, 2015) ##

*   No changes.


## Rails 4.1.12 (June 25, 2015) ##

*   No changes.


## Rails 4.1.11 (June 16, 2015) ##

*   No changes.


## Rails 4.1.10 (March 19, 2015) ##

*   No changes.


## Rails 4.1.9 (January 6, 2015) ##

*   No changes.


## Rails 4.1.8 (November 16, 2014) ##

*   No changes.


## Rails 4.1.7.1 (November 19, 2014) ##

*   No changes.


## Rails 4.1.7 (October 29, 2014) ##

*   No changes.


## Rails 4.1.6 (September 11, 2014) ##

*   No changes.


## Rails 4.1.5 (August 18, 2014) ##

*   No changes.


## Rails 4.1.4 (July 2, 2014) ##

*   No changes.


## Rails 4.1.3 (July 2, 2014) ##

*   No changes.


## Rails 4.1.2 (June 26, 2014) ##

*   No changes.


## Rails 4.1.1 (May 6, 2014) ##

*   No changes.


## Rails 4.1.0 (April 8, 2014) ##

*   `#to_param` returns `nil` if `#to_key` returns `nil`. Fixes #11399.

    *Yves Senn*

*   Ability to specify multiple contexts when defining a validation.

    Example:

        class Person
          include ActiveModel::Validations

          attr_reader :name
          validates_presence_of :name, on: [:verify, :approve]
        end

        person = Person.new
        person.valid?                           # => true
        person.valid?(:verify)                  # => false
        person.errors.full_messages_for(:name)  # => ["Name can't be blank"]
        person.valid?(:approve)                 # => false
        person.errors.full_messages_for(:name)  # => ["Name can't be blank"]

    *Vince Puzzella*

*   `attribute_changed?` now accepts a hash to check if the attribute was
    changed `:from` and/or `:to` a given value.

    Example:

        model.name_changed?(from: "Pete", to: "Ringo")

    *Tejas Dinkar*

*   Fix `has_secure_password` to honor bcrypt-ruby's cost attribute.

    *T.J. Schuck*

*   Updated the `ActiveModel::Dirty#changed_attributes` method to be indifferent between using
    symbols and strings as keys.

    *William Myers*

*   Added new API methods `reset_changes` and `changes_applied` to `ActiveModel::Dirty`
    that control changes state. Previsously you needed to update internal
    instance variables, but now API methods are available.

    *Bogdan Gusiev*

*   Fix `has_secure_password` not to trigger `password_confirmation` validations
    if no `password_confirmation` is set.

    *Vladimir Kiselev*

*   `inclusion` / `exclusion` validations with ranges will only use the faster
    `Range#cover` for numerical ranges, and the more accurate `Range#include?`
    for non-numerical ones.

    Fixes range validations like `:a..:f` that used to pass with values like `:be`.
    Fixes #10593.

    *Charles Bergeron*

*   Fix regression in `has_secure_password`. When a password is set, but a
    confirmation is an empty string, it would incorrectly save.

    *Steve Klabnik* and *Phillip Calvin*

*   Deprecate `Validator#setup`. This should be done manually now in the validator's constructor.

    *Nick Sutterer*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for previous changes.
