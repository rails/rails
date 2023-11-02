*   Support custom content type matchers on ActiveStorage::Blob

    ActiveStorage::Blob has predefined methods for checking if it's an image,
    video, audio or text.

    `Rails.application.config.active_storage.content_type_matchers` allows defining custom
    matchers or overriding the default matchers.

    ```ruby
    Rails.application.config.active_storage.content_type_matchers[:pdf] = -> (c) { c == "application/pdf" }
    blob = ActiveStorage::Blob.last
    blob.pdf? # => true
    ```

    *Petrik de Heus*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activestorage/CHANGELOG.md) for previous changes.
