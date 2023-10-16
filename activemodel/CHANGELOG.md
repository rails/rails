*   Add `ActiveModel::AttributeAssignment.build`

    Imports `ActiveModel::AttributeAssignment.build` implementation from
    `ActiveRecord::Persistence.build` to make individual and bulk construction
    of both `ActiveModel` and `ActiveRecord` objects share the same code.

    *Sean Doyle*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
