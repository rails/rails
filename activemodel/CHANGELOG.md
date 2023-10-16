*   Backport `ActiveRecord::Persistence.create!` and `.create` to Active Model from Active Record

    Migrates `ActiveModel::Persistence.create!` and `.create` implementations
    from `ActiveRecord::Persistence.create!` and `.create` to make individual and
    bulk construction of both `ActiveModel` and `ActiveRecord` objects share the
    same code.

    *Sean Doyle*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
