*   Add possibility to render partial from subfolder with inheritance.

    Partial started with `/` will be found as absolute path. Allow to template inheritance to render partial inside subfolders. Partials with slash in path name can be found only from views root folder. To be sure that `to_partial_path` will return path prepended with leading slash. Thus behaviour of rendering model has been not changed.

    *Alexey Osipenko*

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
