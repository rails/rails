## Rails 6.0.0.alpha (Unreleased) ##

*   Introduced Model.where.any method
    Designed to pass several conditions to where
    that should be joined with OR predicate.
    Only accepts a Hash now.

    ``` ruby
    User.where.any(name: 'Jon', id: 1)
    # SELECT * FROM users WHERE name = 'Jon' OR id = 1
    
    User.joins(:manager).where.any(name: 'Jon', managers: {name: 'Bob'})
    # SELECT * FROM users LEFT managers ON managers.id = users.manager_id 
    #   WHERE name = 'Jon' OR managers.name = 'Bob'
    ```

    *Bogdan Gusiev*

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
