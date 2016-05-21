*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   Introduce ActiveRecord::TransactionSerializationError for catching
    transaction serialization failures or deadlocks.

    *Erol Fornoles*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
