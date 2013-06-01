*   Added new API methods `reset_changes` and `changed_applied` to AM::Dirty
    that control changes state. Previsously you needed to update internal
    instance variables, but now API methods are available.

    *Bogdan Gusiev*

*   Fix regression in has_secure_password. When a password is set, but a
    confirmation is an empty string, it would incorrectly save.

    *Steve Klabnik* and *Phillip Calvin*

*   Deprecate `Validator#setup`. This should be done manually now in the validator's constructor.

    *Nick Sutterer*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for previous changes.
