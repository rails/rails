


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activestorage/CHANGELOG.md) for previous changes.


*   Add ability to customize the Blob#key per Model and attribute basis. Active Storage will save the Blob's attachment on the specified service at the configured key. You can also _interpolate_ values in it automatically with configurable procs.

    ```ruby
    # app/models/user.rb
    has_one_attached :avatar,
                     key: ':tenant/users/:record_id/avatar'

    # with the following configuration
    config.active_storage.key_interpolation_procs = {
      tenant:    ->(record, attachable) { Apartment::Tenant.current.parameterize },
      record_id: ->(record, attachable) { record.id }
    }
    ```

    *František Rokůsek*
