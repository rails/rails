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
