*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

*   Automatically set inverse association for associations with `foreign_key`.

    Fixes #24527.

    *Seva Orlov*

    *Johannes Opper*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
