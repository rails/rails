*   Fix bug allowing destruction of nested objects when validates length fails afterwards.
    Fixes #3961
    
    * Tom Caspy*

*   Fix has_secure_password. `password_confirmation` validations are triggered
    even if no `password_confirmation` is set.

    *Vladimir Kiselev*

*   `inclusion` / `exclusion` validations with ranges will only use the faster
    `Range#cover` for numerical ranges, and the more accurate `Range#include?`
    for non-numerical ones.

    Fixes range validations like `:a..:f` that used to pass with values like `:be`.
    Fixes #10593

    *Charles Bergeron*

*   Fix regression in has_secure_password. When a password is set, but a
    confirmation is an empty string, it would incorrectly save.

    *Steve Klabnik* and *Phillip Calvin*

*   Deprecate `Validator#setup`. This should be done manually now in the validator's constructor.

    *Nick Sutterer*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md) for previous changes.
