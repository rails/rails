*   Fix logging edge case where if an attribute was of the binary type and
    was provided as a Hash.

    *Jon Moss*

*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   Introduce ActiveRecord::TransactionSerializationError for catching
    transaction serialization failures or deadlocks.

    *Erol Fornoles*

*   Use `take` instead of `first` in `ActiveRecord::Relation#first_or_create`, 
    `#first_or_create!` and `#first_or_initialize`.
     
    *Guilherme Goettems Schneider*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
