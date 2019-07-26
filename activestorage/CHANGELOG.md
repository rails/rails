*   Add `config.active_storage.draw_routes` to disable Active Storage routes.

    *Gannon McGibbon*

*   Image analysis is skipped if ImageMagick returns an error.

    `ActiveStorage::Analyzer::ImageAnalyzer#metadata` would previously raise a
    `MiniMagick::Error`, which caused persistent `ActiveStorage::AnalyzeJob`
    failures. It now logs the error and returns `{}`, resulting in no metadata
    being added to the offending image blob.

    *George Claghorn*

*   Method calls on singular attachments return `nil` when no file is attached.

    Previously, assuming the following User model, `user.avatar.filename` would
    raise a `Module::DelegationError` if no avatar was attached:

    ```ruby
    class User < ApplicationRecord
      has_one_attached :avatar
    end
    ```

    They now return `nil`.

    *Matthew Tanous*

*   The mirror service supports direct uploads.

    New files are directly uploaded to the primary service. When a
    directly-uploaded file is attached to a record, a background job is enqueued
    to copy it to each secondary service.

    Configure the queue used to process mirroring jobs by setting
    `config.active_storage.queues.mirror`. The default is `:active_storage_mirror`.

    *George Claghorn*

*   The S3 service now permits uploading files larger than 5 gigabytes.

    When uploading a file greater than 100 megabytes in size, the service
    transparently switches to [multipart uploads](https://docs.aws.amazon.com/AmazonS3/latest/dev/mpuoverview.html)
    using a part size computed from the file's total size and S3's part count limit.

    No application changes are necessary to take advantage of this feature. You
    can customize the default 100 MB multipart upload threshold in your S3
    service's configuration:

    ```yaml
    production:
      service: s3
      access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
      secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
      region: us-east-1
      bucket: my-bucket
      upload:
        multipart_threshold: <%= 250.megabytes %>
    ```

    *George Claghorn*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/activestorage/CHANGELOG.md) for previous changes.
