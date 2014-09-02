*   Passwords with spaces only allowed in `ActiveModel::SecurePassword`.

    Presence validation can be used to restore old behavior.

    *Yevhene Shemet*

*   Validate options passed to `ActiveModel::Validations.validate`.

    Preventing, in many cases, the simple mistake of using `validate` instead of `validates`.

    *Sonny Michaud*

*   Deprecate `reset_#{attribute}` in favor of `restore_#{attribute}`.

    These methods may cause confusion with the `reset_changes` that behaves differently
    of them.

*   Deprecate `ActiveModel::Dirty#reset_changes` in favor of `#clear_changes_information`.

    This method name is causing confusion with the `reset_#{attribute}`
    methods. While `reset_name` set the value of the name attribute for the
    previous value `reset_changes` only discard the changes and previous
    changes.

*   Added `restore_attributes` method to `ActiveModel::Dirty` API to restore all the
    changed values to the previous data.

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
