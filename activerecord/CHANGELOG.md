*   Deprecate `ConnectionAdapters::SchemaStatements#distinct`,
    as it is no longer used by internals.

    *Ben Woosley#

*   Fix pending migrations error when loading schema and `ActiveRecord::Base.table_name_prefix`
    is not blank.

    Call `assume_migrated_upto_version` on connection to prevent it from first
    being picked up in `method_missing`.

    In the base class, `Migration`, `method_missing` expects the argument to be a
    table name, and calls `proper_table_name` on the arguments before sending to
    `connection`. If `table_name_prefix` or `table_name_suffix` is used, the schema
    version changes to `prefix_version_suffix`, breaking `rake test:prepare`.

    Fixes #10411.

    *Kyle Stevens*

*   Method `read_attribute_before_type_cast` should accept input as symbol.

    *Neeraj Singh*

*   Confirm a record has not already been destroyed before decrementing counter cache.

    *Ben Tucker*

*   Fixed a bug in `ActiveRecord#sanitize_sql_hash_for_conditions` in which
    `self.class` is an argument to `PredicateBuilder#build_from_hash`
    causing `PredicateBuilder` to call non-existent method
    `Class#reflect_on_association`.

    *Zach Ohlgren*

*   While removing index if column option is missing then raise IrreversibleMigration exception.

    Following code should raise `IrreversibleMigration`. But the code was
    failing since options is an array and not a hash.

        def change
          change_table :users do |t|
            t.remove_index [:name, :email]
          end
        end

    Fix was to check if the options is a Hash before operating on it.

    Fixes #10419.

    *Neeraj Singh*

*   Do not overwrite manually built records during one-to-one nested attribute assignment

    For one-to-one nested associations, if you build the new (in-memory)
    child object yourself before assignment, then the NestedAttributes
    module will not overwrite it, e.g.:

        class Member < ActiveRecord::Base
          has_one :avatar
          accepts_nested_attributes_for :avatar

          def avatar
            super || build_avatar(width: 200)
          end
        end

        member = Member.new
        member.avatar_attributes = {icon: 'sad'}
        member.avatar.width # => 200

    *Olek Janiszewski*

*   fixes bug introduced by #3329.  Now, when autosaving associations,
    deletions happen before inserts and saves.  This prevents a 'duplicate
    unique value' database error that would occur if a record being created had
    the same value on a unique indexed field as that of a record being destroyed.

    *Johnny Holton*

*   Handle aliased attributes in ActiveRecord::Relation.

    When using symbol keys, ActiveRecord will now translate aliased attribute names to the actual column name used in the database:

    With the model

        class Topic
          alias_attribute :heading, :title
        end

    The call

        Topic.where(heading: 'The First Topic')

    should yield the same result as

        Topic.where(title: 'The First Topic')

    This also applies to ActiveRecord::Relation::Calculations calls such as `Model.sum(:aliased)` and `Model.pluck(:aliased)`.

    This will not work with SQL fragment strings like `Model.sum('DISTINCT aliased')`.

    *Godfrey Chan*

*   Mute `psql` output when running rake db:schema:load.

    *Godfrey Chan*

*   Trigger a save on `has_one association=(associate)` when the associate contents have changed.

    Fix #8856.

    *Chris Thompson*

*   Abort a rake task when missing db/structure.sql like `db:schema:load` task.

    *kennyj*

*   rake:db:test:prepare falls back to original environment after execution.

    *Slava Markevich*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/activerecord/CHANGELOG.md) for previous changes.
