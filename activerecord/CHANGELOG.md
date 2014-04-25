*   When using a custom `join_table` name on a `habtm`, rails was not saving it
    on Reflections. This causes a problem when rails loads fixtures, because it
    uses the reflections to set database with fixtures.

    Fixes #14845.

    *Kassio Borges*

*   Reset the cache when modifying a Relation with cached Arel.
    Additionally display a warning message to make the user aware.

    *Yves Senn*

*   PostgreSQL should internally use `:datetime` consistently for TimeStamp. Assures
    different spellings of timestamps are treated the same.

    Example:

        mytimestamp.simplified_type('timestamp without time zone')
        # => :datetime
        mytimestamp.simplified_type('timestamp(6) without time zone')
        # => also :datetime (previously would be :timestamp)

    See #14513.

    *Jefferson Lai*

*   `ActiveRecord::Base.no_touching` no longer triggers callbacks or start empty transactions.

    Fixes #14841.

    *Lucas Mazza*

*   Fix name collision with `Array#select!` with `Relation#select!`.

    Fixes #14752.

    *Earl St Sauver*

*   Fixed unexpected behavior for `has_many :through` associations going through a scoped `has_many`.

    If a `has_many` association is adjusted using a scope, and another `has_many :through`
    uses this association, then the scope adjustment is unexpectedly neglected.

    Fixes #14537.

    *Jan Habermann*

*   `@destroyed` should always be set to `false` when an object is duped.

    *Kuldeep Aggarwal*

*   Fixed has_many association to make it support irregular inflections.

    Fixes #8928.

    *arthurnn*, *Javier Goizueta*

*   Fixed a problem where count used with a grouping was not returning a Hash.

    Fixes #14721.

    *Eric Chahin*

*   `sanitize_sql_like` helper method to escape a string for safe use in a SQL
    LIKE statement.

    Example:

        class Article
          def self.search(term)
            where("title LIKE ?", sanitize_sql_like(term))
          end
        end

        Article.search("20% _reduction_")
        # => Query looks like "... title LIKE '20\% \_reduction\_' ..."

    *Rob Gilson*, *Yves Senn*

*   Do not quote uuid default value on `change_column`.

    Fixes #14604.

    *Eric Chahin*

*   The comparison between `Relation` and `CollectionProxy` should be consistent.

    Example:

        author.posts == Post.where(author_id: author.id)
        # => true
        Post.where(author_id: author.id) == author.posts
        # => true

    Fixes #13506.

    *Lauro Caetano*

*   Calling `delete_all` on an unloaded `CollectionProxy` no longer
    generates a SQL statement containing each id of the collection:

    Before:

        DELETE FROM `model` WHERE `model`.`parent_id` = 1
        AND `model`.`id` IN (1, 2, 3...)

    After:

        DELETE FROM `model` WHERE `model`.`parent_id` = 1

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Fixed error for aggregate methods (`empty?`, `any?`, `count`) with `select`
    which created invalid SQL.

    Fixes #13648.

    *Simon Woker*

*   PostgreSQL adapter only warns once for every missing OID per connection.

    Fixes #14275.

    *Matthew Draper*, *Yves Senn*

*   PostgreSQL adapter automatically reloads it's type map when encountering
    unknown OIDs.

    Fixes #14678.

    *Matthew Draper*, *Yves Senn*

*   Fix insertion of records via `has_many :through` association with scope.

    Fixes #3548.

    *Ivan Antropov*

*   Auto-generate stable fixture UUIDs on PostgreSQL.

    Fixes: #11524

    *Roderick van Domburg*

*   Fixed a problem where an enum would overwrite values of another enum
    with the same name in an unrelated class.

    Fixes #14607.

    *Evan Whalen*

*   PostgreSQL and SQLite string columns no longer have a default limit of 255.

    Fixes #13435, #9153.

    *Vladimir Sazhin*, *Toms Mikoss*, *Yves Senn*

*   Make possible to have an association called `records`.

    Fixes #11645.

    *prathamesh-sonpatki*

*   `to_sql` on an association now matches the query that is actually executed, where it
    could previously have incorrectly accrued additional conditions (e.g. as a result of
    a previous query). CollectionProxy now always defers to the association scope's
    `arel` method so the (incorrect) inherited one should be entirely concealed.

    Fixes #14003.

    *Jefferson Lai*

*   Block a few default Class methods as scope name.

    For instance, this will raise:

        scope :public, -> { where(status: 1) }

    *arthurnn*

*   Fixed error when using `with_options` with lambda.

    Fixes #9805.

    *Lauro Caetano*

*   Switch `sqlite3:///` URLs (which were temporarily
    deprecated in 4.1) from relative to absolute.

    If you still want the previous interpretation, you should replace
    `sqlite3:///my/path` with `sqlite3:my/path`.

    *Matthew Draper*

*   Treat blank UUID values as `nil`.

    Example:

        Sample.new(uuid_field: '') #=> <Sample id: nil, uuid_field: nil>

    *Dmitry Lavrov*

*   Enable support for materialized views on PostgreSQL >= 9.3.

    *Dave Lee*

*   The PostgreSQL adapter supports custom domains. Fixes #14305.

    *Yves Senn*

*   PostgreSQL `Column#type` is now determined through the corresponding OID.
    The column types stay the same except for enum columns. They no longer have
    `nil` as type but `enum`.

    See #7814.

    *Yves Senn*

*   Fixed error when specifying a non-empty default value on a PostgreSQL array column.

    Fixes #10613.

    *Luke Steensen*

*   Make possible to change `record_timestamps` inside Callbacks.

    *Tieg Zaharia*

*   Fixed error where .persisted? throws SystemStackError for an unsaved model with a
    custom primary key that didn't save due to validation error.

    Fixes #14393.

    *Chris Finne*

*   Introduce `validate` as an alias for `valid?`.

    This is more intuitive when you want to run validations but don't care about the return value.

    *Henrik Nyh*

*   Create indexes inline in CREATE TABLE for MySQL.

    This is important, because adding an index on a temporary table after it has been created
    would commit the transaction.

    It also allows creating and dropping indexed tables with fewer queries and fewer permissions
    required.

    Example:

        create_table :temp, temporary: true, as: "SELECT id, name, zip FROM a_really_complicated_query" do |t|
          t.index :zip
        end
        # => CREATE TEMPORARY TABLE temp (INDEX (zip)) AS SELECT id, name, zip FROM a_really_complicated_query

    *Cody Cutrer*, *Steve Rice*, *Rafael Mendonça Franca*

*   Save `has_one` association even if the record doesn't changed.

    Fixes #14407.

    *Rafael Mendonça França*

*   Use singular table name in generated migrations when
    `ActiveRecord::Base.pluralize_table_names` is `false`.

    Fixes #13426.

    *Kuldeep Aggarwal*

*   `touch` accepts many attributes to be touched at once.

    Example:

        # touches :signed_at, :sealed_at, and :updated_at/on attributes.
        Photo.last.touch(:signed_at, :sealed_at)

    *James Pinto*

*   `rake db:structure:dump` only dumps schema information if the schema
    migration table exists.

    Fixes #14217.

    *Yves Senn*

*   Reap connections that were checked out by now-dead threads, instead
    of waiting until they disconnect by themselves. Before this change,
    a suitably constructed series of short-lived threads could starve
    the connection pool, without ever having more than a couple alive at
    the same time.

    *Matthew Draper*

*   `pk_and_sequence_for` now ensures that only the pg_depend entries
    pointing to pg_class, and thus only sequence objects, are considered.

    *Josh Williams*

*   `where.not` adds `references` for `includes` like normal `where` calls do.

    Fixes #14406.

    *Yves Senn*

*   Extend fixture `$LABEL` replacement to allow string interpolation.

    Example:

        martin:
          email: $LABEL@email.com

        users(:martin).email # => martin@email.com

    *Eric Steele*

*   Add support for `Relation` be passed as parameter on `QueryCache#select_all`.

    Fixes #14361.

    *arthurnn*

*   Passing an Active Record object to `find` is now deprecated.  Call `.id`
    on the object first.

*   Passing an Active Record object to `find` or `exists?` is now deprecated.
    Call `.id` on the object first.

*   Only use BINARY for MySQL case sensitive uniqueness check when column has a case insensitive collation.

    *Ryuta Kamizono*

*   Support for MySQL 5.6 fractional seconds.

    *arthurnn*, *Tatsuhiko Miyagawa*

*   Support for Postgres `citext` data type enabling case-insensitive where
    values without needing to wrap in UPPER/LOWER sql functions.

    *Troy Kruthoff*, *Lachlan Sylvester*

*   Allow strings to specify the `#order` value.

    Example:

        Model.order(id: 'asc').to_sql == Model.order(id: :asc).to_sql

    *Marcelo Casiraghi*, *Robin Dupret*

*   Dynamically register PostgreSQL enum OIDs. This prevents "unknown OID"
    warnings on enum columns.

    *Dieter Komendera*

*   `includes` is able to detect the right preloading strategy when string
    joins are involved.

    Fixes #14109.

    *Aaron Patterson*, *Yves Senn*

*   Fixed error with validation with enum fields for records where the
    value for any enum attribute is always evaluated as 0 during
    uniqueness validation.

    Fixes #14172.

    *Vilius Luneckas* *Ahmed AbouElhamayed*

*   `before_add` callbacks are fired before the record is saved on
    `has_and_belongs_to_many` assocations *and* on `has_many :through`
    associations.  Before this change, `before_add` callbacks would be fired
    before the record was saved on `has_and_belongs_to_many` associations, but
    *not* on `has_many :through` associations.

    Fixes #14144.

*   Fixed STI classes not defining an attribute method if there is a
    conflicting private method defined on its ancestors.

    Fixes #11569.

    *Godfrey Chan*

*   Coerce strings when reading attributes. Fixes #10485.

    Example:

        book = Book.new(title: 12345)
        book.save!
        book.title # => "12345"

    *Yves Senn*

*   Deprecate half-baked support for PostgreSQL range values with excluding beginnings.
    We currently map PostgreSQL ranges to Ruby ranges. This conversion is not fully
    possible because the Ruby range does not support excluded beginnings.

    The current solution of incrementing the beginning is not correct and is now
    deprecated. For subtypes where we don't know how to increment (e.g. `#succ`
    is not defined) it will raise an ArgumentException for ranges with excluding
    beginnings.

    *Yves Senn*

*   Support for user created range types in PostgreSQL.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activerecord/CHANGELOG.md) for previous changes.
