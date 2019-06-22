*   Keep part when scope option has value.

    When a route was defined within an optional scope, if that route didn't
    take parameters the scope was lost when using path helpers. This commit
    ensures scope is kept both when the route takes parameters or when it
    doesn't.

    Fixes #33219.

    *Alberto Almagro*

*   Added `deep_transform_keys` and `deep_transform_keys!` methods to ActionController::Parameters.

    *Gustavo Gutierrez*

*   Calling `ActionController::Parameters#transform_keys/!` without a block now returns
    an enumerator for the parameters instead of the underlying hash.

    *Eugene Kenny*

*   Fix strong parameters blocks all attributes even when only some keys are invalid (non-numerical).
    It should only block invalid key's values instead.

    *Stan Lo*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.
