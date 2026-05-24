**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Custom Active Storage Backends
==============================

This guide covers the contract for using Active Storage without Active Record,
or with blob, attachment, and variant records stored by a third-party backend.

After reading this guide, you will know:

* How to configure custom Active Storage persistence classes.
* What owner classes must provide to use `has_one_attached` and
  `has_many_attached` without inheriting from `ActiveRecord::Base`.
* What API a custom `Blob`, `Attachment`, and `VariantRecord` class must
  implement.
* Which default Active Storage features remain Active Record-specific.

--------------------------------------------------------------------------------

Overview
--------

Active Storage's default persistence classes are Active Record models:
`ActiveStorage::Blob`, `ActiveStorage::Attachment`, and
`ActiveStorage::VariantRecord`. Applications that do not load Active Record can
replace those classes with backend-specific implementations:

```ruby
# config/application.rb
config.active_storage.blob_class = "MyApp::Storage::Blob"
config.active_storage.attachment_class = "MyApp::Storage::Attachment"
config.active_storage.variant_record_class = "MyApp::Storage::VariantRecord"
```

The three settings are all-or-nothing. Configure all three classes together, or
leave all three at their defaults.

WARNING: Mixing Active Record owners with custom Active Storage storage classes
is not supported. Active Record owners use Active Record associations that point
at the default Active Storage tables. Non-Active Record owners use the configured
custom classes. Choose one storage model for the application.

Using Active Storage Without Active Record
------------------------------------------

Applications that do not use `rails/all` must still load the framework pieces
Active Storage depends on:

```ruby
# config/application.rb
require "rails"
require "action_controller/railtie"
require "active_job/railtie"
require "active_storage/engine"
```

The backend gem should make its classes loadable before Active Storage validates
configuration:

```ruby
module MyBackend
  class Railtie < Rails::Railtie
    initializer "my_backend.active_storage", before: "active_storage.class_indirection" do |app|
      app.config.active_storage.blob_class = "MyBackend::Blob"
      app.config.active_storage.attachment_class = "MyBackend::Attachment"
      app.config.active_storage.variant_record_class = "MyBackend::VariantRecord"
    end

    initializer "my_backend.active_storage.services", after: "active_storage.class_indirection" do |app|
      ActiveStorage::Services.setup_from_app_config(app)
    end
  end
end
```

The default Active Record blob class normally initializes the service registry
when it loads. A custom backend that does not load `ActiveStorage::Blob` must
call `ActiveStorage::Services.setup_from_app_config(app)` itself.

Owner Class Contract
--------------------

A non-Active Record owner can declare attachments by including
`ActiveStorage::Attached::Model` and providing callback and lookup hooks:

```ruby
class Message
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveStorage::Attached::Model
  extend ActiveModel::Callbacks

  define_model_callbacks :save, :destroy, :commit

  def self.find(id)
    # Return an owner instance or raise ActiveStorage::RecordNotFound.
  end

  has_one_attached :avatar
  has_many_attached :images

  def persisted?
    # Must reflect whether the record currently exists in the backend: false
    # before the first save and after destroy, true while it is stored. Active
    # Storage relies on it to load attachments and to clean them up.
    id.present? && backend_exists?(id)
  end

  def save
    return false unless valid?

    run_callbacks(:save) { persist_to_backend }
    # Guard the :commit callbacks so the same owner works whether or not it
    # defines them (see the note on optional :commit callbacks below).
    run_callbacks(:commit) { true } if self.class.respond_to?(:_commit_callbacks, true)
    true
  end

  def destroy
    # Remove the record inside the destroy callbacks. To veto a destroy,
    # `throw :abort` from a before_destroy callback; returning false without
    # aborting still runs the after_destroy callbacks. Fire :commit only when
    # the destroy actually ran, so an aborted destroy does not commit.
    destroyed = false
    run_callbacks(:destroy) do
      delete_from_backend
      destroyed = true
    end
    run_callbacks(:commit) { true } if destroyed && self.class.respond_to?(:_commit_callbacks, true)
  end
end
```

The `:commit` callback chain is recommended. If it is absent, Active Storage
uploads files in the `:save` callback, before the owner backend has commit-like
semantics.

A destroyed owner cleans up its attachments in an `after_destroy` callback, and
applies each attachment's `dependent:` option. Active Storage runs that cleanup
only when the owner is no longer `persisted?`, evaluated *during* the
`after_destroy` callbacks (that is, before `#destroy` returns). Two requirements
follow, mirroring how Active Record runs `dependent: :destroy` inside the destroy
transaction:

* Remove the backend record (or `throw :abort` to cancel) from *within*
  `run_callbacks(:destroy) { ... }`, as in the example above. Deleting the record
  after `run_callbacks(:destroy)` returns leaves it `persisted?` while the
  `after_destroy` callbacks run, so Active Storage skips cleanup and the
  attachment rows are orphaned. Returning `false` without `throw :abort` does not
  cancel the destroy: the `after_destroy` callbacks still run.
* `persisted?` must already return `false` inside those `after_destroy` callbacks.
  A `persisted?` that only checks `id.present?` is insufficient, because the id
  survives destruction; it must reflect whether the record still exists in the
  backend.

When the owner defines `:commit` callbacks, dependent blob purges are deferred to
`after_commit`; define `:rollback` callbacks too so a rolled-back destroy cancels
those purges immediately rather than on the owner's next save.

Custom owner classes must define `.find(id)`, an `#id` reader, and an overridden
`#persisted?` before calling `has_one_attached` or `has_many_attached`.
Attachment rows use `record_type` and `record_id` to resolve owners. These
hooks are validated when attachments are declared: a missing `.find`, a missing
`#id`, or relying on the default `ActiveModel::API#persisted?` raises
`ActiveStorage::OwnerContractMissing`.

`persisted?` must return `true` only once the owner has been saved. Active
Storage skips attachment lookups for non-persisted owners, so a record that
reuses a previously stored `id` (for example a preassigned primary key) does not
load another record's attachments before it is saved. The default
`ActiveModel::API#persisted?` returns `false`, so owners that assign their own
ids must override it to reflect their stored state.

Blob Class Contract
-------------------

A custom blob class represents the uploaded file metadata and service key. It
must provide the class methods Active Storage calls when building and resolving
attachments:

```ruby
class MyBackend::Blob
  class << self
    def services; ActiveStorage::Services.registry; end
    def services=(registry); ActiveStorage::Services.registry = registry; end
    def service; ActiveStorage::Services.default; end
    def service=(service); ActiveStorage::Services.default = service; end

    def find(id); end
    def find_signed!(signed_id, record: nil, purpose: :blob_id); end
    def build_after_unfurling(key: nil, io:, filename:, content_type: nil, metadata: nil, service_name: nil, identify: true, record: nil); end
    def create_and_upload!(key: nil, io:, filename:, content_type: nil, metadata: nil, service_name: nil, identify: true, record: nil); end
    def create_before_direct_upload!(key: nil, filename:, byte_size:, checksum:, content_type: nil, metadata: nil, service_name: nil, record: nil); end
    def scope_for_strict_loading; end
  end

  def id; end
  def signed_id(purpose: :blob_id, expires_in: nil, expires_at: nil); end
  def key; end
  def filename; end # ActiveStorage::Filename-compatible
  def content_type; end
  def byte_size; end
  def checksum; end
  def metadata; end
  def service_name; end
  def created_at; end
  def save!; end
  def persisted?; end
  def service; end
  def service_url_for_direct_upload(expires_in: ActiveStorage.service_urls_expire_in); end
  def service_headers_for_direct_upload; end

  def identify_without_saving; end
  def analyze_without_saving; end
  def analyzed?; end
  def upload_without_unfurling(io); end
  def url(expires_in: ActiveStorage.service_urls_expire_in, disposition: :inline, filename: nil, **options); end
  def download(&block); end
  def download_chunk(range); end
  def open(tmpdir: nil, &block); end
  def variant(transformations); end
  def preview(transformations); end
  def preview_image; end
  def representation(transformations); end
  # Temporary IO used before upload for immediate analysis and variants.
  def local_io; end
  def local_io=(io); end
  # Required: return an enumerable of Attachment instances with this blob's id.
  # CreateOneOfMany#find_attachment iterates this when an existing blob is
  # attached to multiple records.
  def attachments
    ActiveStorage.attachment_class.where(blob_id: id)
  end

  def destroy; end
  def purge; end
  def purge_later; end
  def ==(other); end
end
```

Active Storage's controllers read these blob attributes directly. Direct upload
responses use `id`, `key`, `filename.to_s`, `content_type`, `metadata`,
`service_name`, `byte_size`, `checksum`, `created_at`, `signed_id`,
`service_url_for_direct_upload`, and `service_headers_for_direct_upload`.
Direct upload metadata must not allow clients to set Active Storage's protected
metadata keys (`analyzed`, `identified`, and `composed`); use
`ActiveStorage.filter_blob_metadata(metadata)` or equivalent filtering in
`create_before_direct_upload!`.

The object returned by `scope_for_strict_loading` must respond to
`find_signed!`, because Active Storage controllers call
`ActiveStorage.blob_class.scope_for_strict_loading.find_signed!(...)`.

Blob instances should include `GlobalID::Identification` or otherwise serialize
correctly through Active Job, because analysis and purge jobs receive blob
instances.

Lookup methods (`find`, `find_signed!`, and the owner's `.find`) must raise
`ActiveStorage::RecordNotFound` when a record is missing -- translate the
backend's native error (for example `Aws::Record::Errors::RecordNotFound`)
rather than letting it leak. Active Storage's analysis, preview, variant, and
purge jobs `discard_on ActiveStorage::RecordNotFound` (including when the record
vanishes while the job's arguments are deserialized), so a conforming backend
gets a clean discard when a record is deleted before its job runs. A backend
that raises a different error instead leaves those jobs to retry and eventually
exhaust their attempts.

Blob instances should include `ActiveStorage::Servable`, or provide compatible
`content_type_for_serving` and `forced_disposition_for_serving` methods used by
`url` when generating service URLs for the serving controllers.

The `local_io` accessor is required for `analyze: :immediately` and variants
configured to process immediately.

If blobs can be previewed, the blob class must provide `preview_image`, usually
by including `ActiveStorage::Attached::Model` and declaring
`has_one_attached :preview_image` on the blob class.

`attachments` must return the attachments for the blob. Active Storage uses it
when deduplicating `has_many_attached` changes.

`destroy` must protect shared blobs by raising
`ActiveStorage::ForeignKeyViolation` while attachments still reference the blob.
Normal purge paths destroy the attachment first, so single-owner purges can
still remove the blob and service object.

When `config.active_storage.track_variants` is enabled, `destroy` must also
destroy this blob's records from `ActiveStorage.variant_record_class`, so tracked
variants and their attached image records are cleaned up with the source blob.

Attachment Class Contract
-------------------------

A custom attachment class links an owner record to a blob. It must support the
query API used by the generic attachment builder:

```ruby
class MyBackend::Attachment
  def self.transaction; yield; end
  def self.find_by(record_type:, record_id:, name:); end
  def self.where(attributes = {}); end

  attr_accessor :pending_upload, :immediate_variants_processed

  def record_type; end
  def record_id; end
  def name; end
  def blob_id; end
  def blob; end
  def record; end

  def assign_attributes(attributes); end
  def save!; end
  def persisted?; end
  def new_record?; end
  def destroy; end
  def delete; end
  def purge; end
  def purge_later; end
  def uploaded(io:); end
  def ==(other); end
end
```

`transaction` should be a real backend transaction when the backend supports
one. If it is a no-op, a failed attachment save can leave already-saved metadata
behind unless the backend cleanup path removes it. Active Storage cleans up a
newly-created blob when generic attachment creation fails before upload.

`where(attributes = {})` must return an enumerable relation-like object that
supports:

* `order(*attributes).to_a` — Active Storage orders `has_many_attached`
  collections with `order(:created_at, :id)`, so `order` must accept multiple
  attributes and break ties on later ones.
* `where.not(blob_id: id_or_ids)`
* `each`
* `delete_all`

When Active Storage's generic owner path destroys attachment records, it also
applies the reflection's `dependent:` option. This includes replacing or clearing
attachments and destroying the owner. Therefore `destroy` only needs to delete
the attachment row and run the backend's destroy callbacks for the normal
`has_one_attached` / `has_many_attached` owner path. `destroy` must complete the
destruction or raise an exception. Silently returning `false` or otherwise
halting the destroy is not supported in these dependent-destroy paths.

If your backend destroys attachment records outside the generated Active Storage
paths and wants the same dependent-purge behavior, implement it explicitly in
that custom path and avoid calling it from paths that Active Storage already
handles:

```ruby
def destroy_with_dependent_blob
  blob_to_purge = blob
  destroy

  case dependent
  when :purge
    blob_to_purge&.purge
  when :purge_later
    blob_to_purge&.purge_later
  end
end

private
  def dependent
    record.class.attachment_reflections[name].options.fetch(:dependent, nil)
  end
```

Equality
--------

Custom Blob and Attachment classes should override `==` to compare by class and
primary key, so reloaded instances match the originals:

```ruby
class MyBackend::Blob
  def ==(other)
    other.instance_of?(self.class) && id.present? && id == other.id
  end
end

class MyBackend::Attachment
  def ==(other)
    other.instance_of?(self.class) && id.present? && id == other.id
  end
end
```

Variant Record Class Contract
-----------------------------

When `config.active_storage.track_variants` is enabled, Active Storage stores
variant records through the configured `variant_record_class`. A custom variant
record class must provide:

```ruby
class MyBackend::VariantRecord
  include ActiveStorage::Attached::Model

  has_one_attached :image

  def self.find(id); end
  def self.find_by(blob_id:, variation_digest:); end
  def self.create_or_find_by!(blob_id:, variation_digest:)
    # Yield the new record before saving, matching Active Record.
  end

  def blob_id; end
  def variation_digest; end
end
```

The variant record is itself an attachment owner, so it must satisfy the owner
class contract.

Collection Behavior
-------------------

For non-Active Record owners, generated `*_attachments` and `*_blobs` methods
return lightweight enumerable collection objects.

These collection objects support common enumerable operations such as `each`,
`to_a`, `any?`, `find_by`, `pluck`, `reload`, `reset`, and `delete_all`. They do
not support arbitrary query chaining:

```ruby
message.images_attachments.where(content_type: "image/png")
# raises ActiveStorage::QueryNotSupported
```

Query the backend class directly for backend-specific filtering:

```ruby
MyBackend::Attachment.where(record_type: "Message", record_id: message.id, name: "images")
```

Limitations
-----------

The default Active Record storage backend continues to support SQL joins,
association scopes, `with_attached_*` eager loading, fixtures, and the default
Active Storage database migrations.

Custom non-Active Record backends do not get those Active Record features for
free. In particular:

* `with_attached_*` raises `ActiveStorage::EagerLoadingNotSupported`.
* `strict_loading: true` raises `ArgumentError`.
* SQL joins in the Active Storage overview apply only to the default Active
  Record backend.
* Active Storage fixtures are Active Record-specific.
* `ActiveStorage::Service::MirrorService` uses Active Record's default blob
  service path and is not a supported non-Active Record backend target.

Custom backend integrations may raise or rescue these Active Storage errors:
`ActiveStorage::ConfigurationError`, `ActiveStorage::HybridConfigurationError`,
`ActiveStorage::OwnerContractMissing`, `ActiveStorage::EagerLoadingNotSupported`,
`ActiveStorage::QueryNotSupported`, `ActiveStorage::RecordNotFound`,
`ActiveStorage::RecordNotSaved`, `ActiveStorage::RecordInvalid`,
`ActiveStorage::RecordNotDestroyed`, `ActiveStorage::ForeignKeyViolation`, and
`ActiveStorage::Deadlocked`.

Backend gems should ship their own tests that attach, download, detach, purge,
direct-upload, analyze, and variant-track using their concrete persistence
classes.
