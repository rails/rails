## Rails 5.1.0.alpha ##

*   Remove deprecated `conditions` argument from the `destroy_all` and `delete_all`
    methods in `ActiveRecord::Relation`.

    *Jon Moss*

*   Remove deprecated `uniq`, `uniq!` and `uniq_value` methods from `ActiveRecord::Relation`.

    *Jon Moss*

*   Remove rescue for `ActiveRecord::IrreversibleOrderError`.

    *Jon Moss*

*   Remove deprecated `original_exception` method from `ActiveRecord::StatementInvalid`.

    *Jon Moss*

*   Remove deprecated `load_schema_for` method from `ActiveRecord::Tasks::DatabaseTasks`.

    *Jon Moss*

*   Remove deprecated `ActiveRecord::PredicateBuilder::ClassHandler`.

    *Jon Moss*

*   Fix logging edge case where if an attribute was of the binary type and
    was provided as a Hash.

    *Jon Moss*

*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   Introduce ActiveRecord::TransactionSerializationError for catching
    transaction serialization failures or deadlocks.

    *Erol Fornoles*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
