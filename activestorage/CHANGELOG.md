*   Add `:primary_key` option to the
    `ActiveStorage::Attached::Model::has_one_attachment` and
    `ActiveStorage::Attached::Model::has_many_attachments`
    methods. This is used to specify the method to use as the primary key for
    the relation.
    
    For example:

    ```ruby
    class Message < ApplicationRecord
      # ...
      has_one_attached :file, primary_key: "bigint_id"
      # ...
    end
    ``` 

    *John Isom*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.
