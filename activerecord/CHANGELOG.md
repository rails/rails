## Rails 6.0.0.alpha (Unreleased) ##

*   Add `Relation#pick` for fetching direct type-cast values without instantiating record objects
    or dealing with accessing them from within a plucked array.

    ```
    Person.where(id: 1).pick(:name)
    # SELECT people.name FROM people WHERE id = 1 LIMIT 1
    # => 'David'
    
    Person.where(id: 1).pick(:name, :email_address)
    # SELECT people.name, people.email_address FROM people WHERE id = 1 LIMIT 1
    # => [ 'David', 'david@loudthinking.com' ]
    ```
    
    *DHH*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activerecord/CHANGELOG.md) for previous changes.
