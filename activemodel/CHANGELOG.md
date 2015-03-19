## Rails 4.2.1 (March 19, 2014) ##

* No changes *


## Rails 4.2.0 (December 20, 2014) ##

*   Passwords with spaces only allowed in `ActiveModel::SecurePassword`.

    Presence validation can be used to restore old behavior.

    *Yevhene Shemet*

*   Validate options passed to `ActiveModel::Validations.validate`.

    Preventing, in many cases, the simple mistake of using `validate` instead of `validates`.

    *Sonny Michaud*

*   Deprecate `reset_#{attribute}` in favor of `restore_#{attribute}`.

    These methods may cause confusion with the `reset_changes`, which has
    different behaviour.

    *Rafael Mendonça França*

*   Deprecate `ActiveModel::Dirty#reset_changes` in favor of `#clear_changes_information`.

    Method's name is causing confusion with the `reset_#{attribute}` methods.
    While `reset_name` sets the value of the name attribute to previous value
    `reset_changes` only discards the changes.

    *Rafael Mendonça França*

*   Added `restore_attributes` method to `ActiveModel::Dirty` API which restores
    the value of changed attributes to previous value.

    *Igor G.*

*   Allow proc and symbol as values for `only_integer` of `NumericalityValidator`

    *Robin Mehner*

*   `has_secure_password` now verifies that the given password is less than 72
    characters if validations are enabled.

    Fixes #14591.

    *Akshay Vishnoi*

*   Remove deprecated `Validator#setup` without replacement.

    See #10716.

    *Kuldeep Aggarwal*

*   Add plural and singular form for length validator's default messages.

    *Abd ar-Rahman Hamid*

*   Introduce `validate` as an alias for `valid?`.

    This is more intuitive when you want to run validations but don't care about
    the return value.

    *Henrik Nyh*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activemodel/CHANGELOG.md) for previous changes.
