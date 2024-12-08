*   Add `active_storage_direct_uploads_controller` load hook

    Issue #34961

    Allows users to restrict direct uploads with their own authentication and/or rate limiting.

    ```ruby
    ActiveSupport.on_load :active_storage_direct_uploads_controller do
      before_action :authenticate_user!
      rate_limit to: 10, within: 3.minutes
    end
    ```

    *juanvqz*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md) for previous changes.
