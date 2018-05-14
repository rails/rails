*   Do not call after_commit callbacks when underlying update fails.

    Previously, after_commit callbacks were called during an update within an explicit transaction
    block even when the actual update failed.

    Fixes #29747.

    *Nathan Wenneker*

*   Values constructed using multi-parameter assignment will now use the
    post-type-cast value for rendering in single-field form inputs.

*   Fix logic on disabling commit callbacks so they are not called unexpectedly when errors occur.

    *Brian Durand*

*   Ensure `Associations::CollectionAssociation#size` and `Associations::CollectionAssociation#empty?`
    use loaded association ids if present.

    *Graham Turner*

*   Add support to preload associations of polymorphic associations when not all the records have the requested associations.

    *Dana Sherson*

*   Add `touch_all` method to `ActiveRecord::Relation`.

    Example:

        Person.where(name: "David").touch_all(time: Time.new(2020, 5, 16, 0, 0, 0))

    *fatkodima*, *duggiefresh*

*   Add `ActiveRecord::Base.base_class?` predicate.

    *Bogdan Gusiev*

*   Add custom prefix option to ActiveRecord::Store.store_accessor.

    *Tan Huynh*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*

*   Deprecate `update_attributes`/`!` in favor of `update`/`!`.

    *Eddie Lebow*

*   Add ActiveRecord::Base.create_or_find_by/! to deal with the SELECT/INSERT race condition in
    ActiveRecord::Base.find_or_create_by/! by leaning on unique constraints in the database.

    *DHH*

*   Add `Relation#pick` as short-hand for single-value plucks.

    *DHH*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activerecord/CHANGELOG.md) for previous changes.
