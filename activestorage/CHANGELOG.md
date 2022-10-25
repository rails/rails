*   Add missing preview event to `ActiveStorage::LogSubscriber`

    A `preview` event is being instrumented in `ActiveStorage::Previewer`.
    However it was not added inside ActiveStorage's LogSubscriber class.

    This will allow to have logs for when a preview happens
    in the same fashion as all other ActiveStorage events such as
    `upload` and `download` inside `Rails.logger`.

    *Chedli Bourguiba*

*   Fix retrieving rotation value from FFmpeg on version 5.0+.

    In FFmpeg version 5.0+ the rotation value has been removed from tags.
    Instead the value can be found in side_data_list. Along with
    this update it's possible to have values of -90, -270 to denote the video
    has been rotated.

    *Haroon Ahmed*

*   Touch all corresponding model records after ActiveStorage::Blob is analyzed

    This fixes a race condition where a record can be requested and have a cache entry built, before
    the initial `analyze_later` completes, which will not be invalidated until something else
    updates the record. This also invalidates cache entries when a blob is re-analyzed, which
    is helpful if a bug is fixed in an analyzer or a new analyzer is added.

    *Nate Matykiewicz*

*   Add ability to use pre-defined variants when calling `preview` or
    `representation` on an attachment.

    ```ruby
    class User < ActiveRecord::Base
      has_one_attached :file do |attachable|
        attachable.variant :thumb, resize_to_limit: [100, 100]
      end
    end

    <%= image_tag user.file.representation(:thumb) %>
    ```

    *Richard Böhme*

*   Method `attach` always returns the attachments except when the record
    is persisted, unchanged, and saving it fails, in which case it returns `nil`.

    *Santiago Bartesaghi*

*   Fixes multiple `attach` calls within transaction not uploading files correctly.

    In the following example, the code failed to upload all but the last file to the configured service.
    ```ruby
      ActiveRecord::Base.transaction do
        user.attachments.attach({
          content_type: "text/plain",
          filename: "dummy.txt",
          io: ::StringIO.new("dummy"),
        })
        user.attachments.attach({
          content_type: "text/plain",
          filename: "dummy2.txt",
          io: ::StringIO.new("dummy2"),
        })
      end

      assert_equal 2, user.attachments.count
      assert user.attachments.first.service.exist?(user.attachments.first.key)  # Fails
    ```

    This was addressed by keeping track of the subchanges pending upload, and uploading them
    once the transaction is committed.

    Fixes #41661

    *Santiago Bartesaghi*, *Bruno Vezoli*, *Juan Roig*, *Abhay Nikam*

*   Raise an exception if `config.active_storage.service` is not set.

    If Active Storage is configured and `config.active_storage.service` is not
    set in the respective environment's configuration file, then an exception
    is raised with a meaningful message when attempting to use Active Storage.

    *Ghouse Mohamed*

*   Fixes proxy downloads of files over 5mb

    Previously, trying to view and/or download files larger than 5mb stored in
    services like S3 via proxy mode could return corrupted files at around
    5.2mb or cause random halts in the download. Now,
    `ActiveStorage::Blobs::ProxyController` correctly handles streaming these
    larger files from the service to the client without any issues.

    Fixes #44679

    *Felipe Raul*

*   Saving attachment(s) to a record returns the blob/blobs object

    Previously, saving attachments did not return the blob/blobs that
    were attached. Now, saving attachments to a record with `#attach`
    method returns the blob or array of blobs that were attached to
    the record. If it fails to save the attachment(s), then it returns
    `false`.

    *Ghouse Mohamed*

*   Don't stream responses in redirect mode

    Previously, both redirect mode and proxy mode streamed their
    responses which caused a new thread to be created, and could end
    up leaking connections in the connection pool. But since redirect
    mode doesn't actually send any data, it doesn't need to be
    streamed.

    *Luke Lau*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md) for previous changes.
