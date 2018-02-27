## Rails 6.0.0.alpha (Unreleased) ##

*   Fix `#columsn_for_distinct` of MySQL and PostgreSQL to make
    `ActiveRecord::FinderMethods#limited_ids_for` use correct primary key values
    even if `ORDER BY` columns include other table's primary key.

    Fixes #28364.

    *Takumi Kagiyama*

*   Make `reflection.klass` raise if `polymorphic?` not to be misused.

    Fixes #31876.

    *Ryuta Kamizono*

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
