*   Calling `ActionController::Parameters#transform_keys/!` without a block now returns
    an enumerator for the parameters instead of the underlying hash.

    *Eugene Kenny*

* Fix strong parameters blocks all attributes even when only some keys are invalid (non-numerical). It should only block invalid key's values instead.

    *Stan Lo*

Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.
