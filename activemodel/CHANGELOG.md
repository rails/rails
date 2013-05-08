*   Fix regression in has_secure_password. When a password is set, but a
    confirmation is an empty string, it would incorrectly save.

    *Steve Klabnik* and *Phillip Calvin*

*   Deprecate `Validator#setup`. This should be done manually now in the validator's constructor.

    *Nick Sutterer*

*   Add the `ActiveModel#attribute_method_names` method, which returns an
    array of attribute names and aliases as strings.

    *Patrick Van Stee*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for previous changes.
