## Rails 7.1.2 (November 10, 2023) ##

*   No changes.


## Rails 7.1.1 (October 11, 2023) ##

*   No changes.


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   No changes.


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   Add `expires_at` option to `ActiveStorage::Blob#signed_id`.

    ```ruby
    rails_blob_path(user.avatar, disposition: "attachment", expires_at: 30.minutes.from_now)
    <%= image_tag rails_blob_path(user.avatar.variant(resize: "100x100"), expires_at: 30.minutes.from_now) %>
    ```

    *Aki*

*   Allow attaching File and Pathname when assigning attributes, e.g.

    ```ruby
    User.create!(avatar: File.open("image.jpg"))
    User.create!(avatar: file_fixture("image.jpg"))
    ```

    *Dorian Marié*


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Disables the session in `ActiveStorage::Blobs::ProxyController`
    and `ActiveStorage::Representations::ProxyController`
    in order to allow caching by default in some CDNs as CloudFlare

    Fixes #44136

    *Bruno Prieto*

*   Add `tags` to `ActiveStorage::Analyzer::AudioAnalyzer` output

    *Keaton Roux*

*   Add an option to preprocess variants

    ActiveStorage variants are processed on the fly when they are needed but
    sometimes we're sure that they are accessed and want to processed them
    upfront.

    `preprocessed` option is added when declaring variants.

    ```
    class User < ApplicationRecord
      has_one_attached :avatar do |attachable|
        attachable.variant :thumb, resize_to_limit: [100, 100], preprocessed: true
      end
    end
    ```

    *Shouichi Kamiya*

*   Fix variants not included when eager loading multiple records containing a single attachment

    When using the `with_attached_#{name}` scope for a `has_one_attached` relation,
    attachment variants were not eagerly loaded.

    *Russell Porter*

*   Allow an ActiveStorage attachment to be removed via a form post

    Attachments can already be removed by updating the attachment to be nil such as:
    ```ruby
    User.find(params[:id]).update!(avatar: nil)
    ```

    However, a form cannot post a nil param, it can only post an empty string. But, posting an
    empty string would result in an `ActiveSupport::MessageVerifier::InvalidSignature: mismatched digest`
    error being raised, because it's being treated as a signed blob id.

    Now, nil and an empty string are treated as a delete, which allows attachments to be removed via:
    ```ruby
    User.find(params[:id]).update!(params.require(:user).permit(:avatar))

    ```

    *Nate Matykiewicz*

*   Remove mini_mime usage in favour of marcel.

    We have two libraries that are have similar usage. This change removes
    dependency on mini_mime and makes use of similar methods from marcel.

    *Vipul A M*

*   Allow destroying active storage variants

    ```ruby
    User.first.avatar.variant(resize_to_limit: [100, 100]).destroy
    ```

    *Shouichi Kamiya*, *Yuichiro NAKAGAWA*, *Ryohei UEDA*

*   Add `sample_rate` to `ActiveStorage::Analyzer::AudioAnalyzer` output

    *Matija Čupić*

*   Remove deprecated `purge` and `purge_later` methods from the attachments association.

    *Rafael Mendonça França*

*   Remove deprecated behavior when assigning to a collection of attachments.

    Instead of appending to the collection, the collection is now replaced.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveStorage::Current#host` and `ActiveStorage::Current#host=` methods.

    *Rafael Mendonça França*

*   Remove deprecated invalid default content types in Active Storage configurations.

    *Rafael Mendonça França*

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

*   Safe for direct upload on Libraries or Frameworks

    Enable the use of custom headers during direct uploads, which allows for
    the inclusion of Authorization bearer tokens or other forms of authorization
    tokens through headers.

    *Radamés Roriz*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activestorage/CHANGELOG.md) for previous changes.
