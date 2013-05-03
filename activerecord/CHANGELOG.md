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
