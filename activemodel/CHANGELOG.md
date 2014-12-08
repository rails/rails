*   Deprecate returning `false` as a way to halt callback chains.

    Returning `false` in a `before_` callback will display a
    deprecation warning explaining that the preferred method to halt a callback
    chain is to explicitly `throw(:abort)`.

    *claudiob*


Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activemodel/CHANGELOG.md) for previous changes.
