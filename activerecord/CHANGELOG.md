*   Fixture setup does no longer depend on `ActiveRecord::Base.configurations`.
    This is relevant when `ENV["DATABASE_URL"]` is used in place of a `database.yml`.

    *Yves Senn*

*   Fix mysql2 adapter raises the correct exception when executing a query on a
    closed connection.

    *Yves Senn*

*   Ambiguous reflections are on :through relationships are no longer supported.
    For example, you need to change this:

        class Author < ActiveRecord::Base
          has_many :posts
          has_many :taggings, :through => :posts
        end

        class Post < ActiveRecord::Base
          has_one :tagging
          has_many :taggings
        end

        class Tagging < ActiveRecord::Base
        end

    To this:

        class Author < ActiveRecord::Base
          has_many :posts
          has_many :taggings, :through => :posts, :source => :tagging
        end

        class Post < ActiveRecord::Base
          has_one :tagging
          has_many :taggings
        end

        class Tagging < ActiveRecord::Base
        end

*   Remove column restrictions for `count`, let the database raise if the SQL is
    invalid. The previous behavior was untested and surprising for the user.
    Fixes #5554.

    Example:

        User.select("name, username").count
        # Before => SELECT count(*) FROM users
        # After => ActiveRecord::StatementInvalid

        # you can still use `count(:all)` to perform a query unrelated to the
        # selected columns
        User.select("name, username").count(:all) # => SELECT count(*) FROM users

    *Yves Senn*

*   Rails now automatically detects inverse associations. If you do not set the
    `:inverse_of` option on the association, then Active Record will guess the
    inverse association based on heuristics.

    Note that automatic inverse detection only works on `has_many`, `has_one`,
    and `belongs_to` associations. Extra options on the associations will
    also prevent the association's inverse from being found automatically.

    The automatic guessing of the inverse association uses a heuristic based
    on the name of the class, so it may not work for all associations,
    especially the ones with non-standard names.

    You can turn off the automatic detection of inverse associations by setting
    the `:inverse_of` option to `false` like so:

        class Taggable < ActiveRecord::Base
          belongs_to :tag, inverse_of: false
        end

    *John Wang*

*   Fix `add_column` with `array` option when using PostgreSQL. Fixes #10432

    *Adam Anderson*

*   Usage of `implicit_readonly` is being removed`. Please use `readonly` method
    explicitly to mark records as `readonly.
    Fixes #10615.

    Example:

        user = User.joins(:todos).select("users.*, todos.title as todos_title").readonly(true).first
        user.todos_title = 'clean pet'
        user.save! # will raise error

    *Yves Senn*

*   Fix the `:primary_key` option for `has_many` associations.
    Fixes #10693.

    *Yves Senn*

*   Fix bug where tiny types are incorrectly coerced as boolean when the length is more than 1.

    Fixes #10620.

    *Aaron Peterson*

*   Also support extensions in PostgreSQL 9.1. This feature has been supported since 9.1.

    *kennyj*

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

*   fixes bug introduced by #3329. Now, when autosaving associations,
    deletions happen before inserts and saves. This prevents a 'duplicate
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
