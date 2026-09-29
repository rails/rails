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

These settings may be provided in `config/application.rb`, an environment file,
or `config/initializers`. Custom classes must be independent of the default
Active Record storage models, whose files are excluded from autoloading when a
custom backend is configured.

Active Storage loads Active Record when it is available, including in applications
that require individual framework railties. The `activestorage` gem depends on
`activemodel`, so a custom backend can also run in a bundle without `activerecord`.
Applications using the default backend must include `activerecord` in their
Gemfile; applications using the `rails` gem already have that dependency.

WARNING: Mixing Active Record owners with custom Active Storage storage classes
is not supported. Active Record owners use Active Record associations that point
at the default Active Storage tables. Non-Active Record owners use the configured
custom classes. Choose one storage model for the application.

Using Active Storage without Active Record
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

    initializer "my_backend.active_storage.services", after: :setup_main_autoloader do |app|
      ActiveStorage::Services.setup_from_app_config(app)
    end
  end
end
```

The default Active Record blob class normally initializes the service registry
when it loads. A custom backend that does not load `ActiveStorage::Blob` must
call `ActiveStorage::Services.setup_from_app_config(app)` itself.

Run service setup after `:setup_main_autoloader` so configured classes under
`app/models` can be resolved as well as classes supplied by a gem. Active Storage
configures replacement blob classes with the same services when code reloads.

Backend classes can declare their attachments when the gem is required, before
the application class exists. Active Storage checks storage compatibility after
class configuration is loaded, and validates their service selections when the
backend initializes the service registry. Declarations made after configuration
are checked immediately.

`ActiveStorage::Services.configured?` reports whether setup has completed. Reading
`registry` or `default` before setup raises `ActiveStorage::ConfigurationError`;
this also protects blob classes that delegate their service readers to this
registry. After setup, `default` can be `nil` when every attachment selects a
named service explicitly.

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

  define_model_callbacks :save, :destroy, :commit, :rollback

  attr_accessor :id

  def self.find(id)
    # Return an owner with @persisted = true, or raise ActiveStorage::RecordNotFound.
  end

  def persisted?
    # Must reflect whether the record currently exists in the backend: false
    # before the first save and after destroy, true while it is stored. Active
    # Storage relies on it to load attachments and to clean them up.
    @persisted == true && id.present? && backend_exists?(id)
  end

  has_one_attached :avatar
  has_many_attached :images

  def save
    return false unless valid?

    saved = run_callbacks(:save) do
      next false unless persist_to_backend

      @persisted = true
    end
    return false unless saved

    # This example commits each save immediately. A transactional backend runs
    # these callbacks only after its outermost transaction successfully commits.
    run_callbacks(:commit) { true } if self.class.respond_to?(:_commit_callbacks, true)
    true
  end

  def destroy
    destroyed = run_callbacks(:destroy) do
      next false unless persisted? && delete_from_backend

      @persisted = false
      true
    end
    return false unless destroyed

    run_callbacks(:commit) { true } if self.class.respond_to?(:_commit_callbacks, true)
    true
  end
end
```

The example leaves `persist_to_backend`, `delete_from_backend`, `backend_exists?`,
and `.find` to the owner backend. Persistence and deletion must return `true` on
success and `false` on failure, or raise an exception. Lookup must set
`@persisted = true`, as `save` does above; a new instance leaves it unset, even
when its assigned ID already exists. A `before_save` or
`before_destroy` callback can cancel the operation with `throw :abort`.

An owner must assign its ID and report `persisted?` as `true` inside the
`run_callbacks(:save)` block, before its `after_save` callbacks run. Active
Storage raises `ActiveStorage::OwnerContractMissing` before writing attachment
metadata if either requirement is unmet.

The `:commit` callback chain is recommended. Run it only after a successful backend
commit, and run `:rollback` after restoring a rolled-back transaction. A failed
save must not report a commit. Active Storage uploads only successfully saved
attachment changes whose attachment rows still exist. An unsaved replacement
remains pending when an earlier saved assignment commits. When `:commit` is
absent, uploads and dependent purges run after successful save or destruction.
Active Storage installs its lifecycle callbacks when the first attachment is
declared. With Active Model's `after_save` and `after_destroy` helpers, callbacks
of the same kind run in registration order. The Active Storage callback handles
all attachment names, including those declared after it was installed.

Rollback cancels deferred uploads and purges while keeping current assignments
available for retry. The backend remains responsible for rolling back stored
records. Reloading an owner clears its pending assignments, but preserves saved
attachment work awaiting commit. Duplicating an owner starts with no pending
attachment work.

Owner implementations of `reload` and `initialize_dup` must call
`super` to run Active Storage's cache and lifecycle handling. To make an owner
save atomic with its attachment metadata, the owner backend must wrap
persistence and its save callbacks in the same outer transaction. Active Storage
groups attachment changes in an attachment backend
transaction; it cannot roll back an owner stored by an independent database.

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
  attachment rows are orphaned. Return `false` from the persistence block when
  deletion fails; Active Model skips the `after_destroy` callbacks in that case.
* `persisted?` must already return `false` inside those `after_destroy` callbacks.
  A `persisted?` that only checks `id.present?` is insufficient, because the id
  survives destruction; it must reflect whether the record still exists in the
  backend.

When the owner defines `:commit` callbacks, dependent blob purges are deferred to
`after_commit`; define `:rollback` callbacks too so a rolled-back save or destroy
cancels those purges. Multiple saves before one commit retain the purges from
each successful save.

Custom owner classes must be named classes and define `.find(id)`, a public `#id`
reader, and an overridden public
`#persisted?` before calling `has_one_attached` or `has_many_attached`.
Attachment rows use `record_type` and `record_id` to resolve owners. These
hooks are validated when attachments are declared: a missing `.find`, a missing
`#id`, or relying on the default `ActiveModel::API#persisted?` raises
`ActiveStorage::OwnerContractMissing`.

`id` must be assigned before save callbacks finish. Attachment rows use the
owner's concrete class name, including for subclasses; custom backends do not
infer Active Record's single-table inheritance base class.

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
  include ActiveModel::Serializers::JSON

  class << self
    def services; ActiveStorage::Services.registry; end
    def services=(registry); ActiveStorage::Services.registry = registry; end
    def service; ActiveStorage::Services.default; end
    def service=(service); ActiveStorage::Services.default = service; end

    def find(id); end
    def where(attributes = {}); end
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
  def metadata=(attributes); end
  def service_name; end
  def created_at; end
  def attributes
    %w[id key filename content_type metadata service_name byte_size checksum created_at]
      .index_with { |name| public_send(name) }
  end
  def save!; end
  def persisted?; end
  def service; end
  def service_url_for_direct_upload(expires_in: ActiveStorage.service_urls_expire_in); end
  def service_headers_for_direct_upload; end

  def identify_without_saving; end
  def analyze; end
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
  # Return attachments belonging to this blob, including unsaved inverse records.
  def attachments
    ActiveStorage.attachment_class.where(blob_id: id)
  end

  def destroy; end
  def purge; end
  def purge_later; end
  def ==(other); end
end
```

Direct uploads serialize the blob with `as_json(root: false, methods: :signed_id)`.
Including `ActiveModel::Serializers::JSON` and defining `attributes` supplies this
interface while allowing applications to extend serialization. The response also
includes `service_url_for_direct_upload` and `service_headers_for_direct_upload`.
Direct upload metadata must not allow clients to set Active Storage's protected
metadata keys (`analyzed`, `identified`, and `composed`); use
`ActiveStorage.filter_blob_metadata(metadata)` or equivalent filtering in
`create_before_direct_upload!`.

The object returned by `scope_for_strict_loading` must respond to
`find_signed!`, because Active Storage controllers call
`ActiveStorage.blob_class.scope_for_strict_loading.find_signed!(...)`.

WARNING: Signed IDs are bearer credentials used by the public blob and
representation controllers. `find_signed!` must verify the signature, purpose,
and expiration before looking up the record. Accepting an unsigned ID here
exposes files to anyone who can guess a record ID.

Use matching signing and verification purposes, defaulting to `:blob_id`. For
example, a backend can use the application's Active Storage verifier:

```ruby
def signed_id(purpose: :blob_id, expires_in: nil, expires_at: nil)
  ActiveStorage.verifier.generate(id, purpose: purpose.to_s,
    expires_in: expires_in, expires_at: expires_at)
end

def self.find_signed!(signed_id, record: nil, purpose: :blob_id)
  find(ActiveStorage.verifier.verify(signed_id, purpose: purpose.to_s))
end
```

Invalid, expired, or wrong-purpose signatures must raise
`ActiveSupport::MessageVerifier::InvalidSignature`; the serving controllers
return HTTP 404 for that error. A valid signature for a deleted blob must raise
`ActiveStorage::RecordNotFound`.

Blob instances should include `GlobalID::Identification` or otherwise serialize
correctly through Active Job, because analysis and purge jobs receive blob
instances. A Global ID argument is deserialized with `GlobalID::Locator.fetch`,
and the default locator looks the record up through `where(primary_key => ids)`
rather than `find`, handing the ids over as strings. A blob class using that
default therefore needs a `where` matching its primary key that casts a string id
the way `find` does. One that returns nothing instead makes every enqueued blob
argument read as a deleted record, and a missing or raising `where` fails the
deserialization outright. A backend that registers its own locator or Active Job
serializer supplies its own lookup instead.

Lookup methods (`find`, `find_signed!`, and the owner's `.find`) must raise
`ActiveStorage::RecordNotFound` when a record is missing -- translate the
backend's native error (for example `Aws::Record::Errors::RecordNotFound`)
rather than letting it leak. Active Storage's analysis, preview, variant, and
purge jobs `discard_on ActiveStorage::RecordNotFound`, so a conforming backend
gets a clean discard when a record is deleted before its job runs. An error that
matches no handler, neither itself nor through its `cause` chain, escapes Active
Job, and the queue backend decides what happens to the job.

A record that vanishes before the job's arguments are deserialized takes a
different path, because `GlobalID::Locator.fetch` queries through `where` rather
than `find`. An empty result becomes
`ActiveJob::DeserializationError::RecordNotFound`, which those same jobs also
`discard_on`, so `where` should return an empty result rather than raise. A
`where` that raises is wrapped as `GlobalID::Locator::RecordUnavailable` and then
as a plain `ActiveJob::DeserializationError`. That still discards when the
original error was `ActiveStorage::RecordNotFound`, because rescue handlers
follow the `cause` chain, but any error that matches no handler escapes
Active Job the same way.

Blob instances must include `ActiveStorage::Servable`, or provide equivalent
`content_type_for_serving` and `forced_disposition_for_serving` methods. Proxy
controllers call these methods directly. The backend's `url` must also honor
them when generating service URLs: force binary content types and attachment
disposition for unsafe content such as HTML and SVG, following the application's
Active Storage configuration. Passing an unverified content type straight to the
storage service is not sufficient.

Backend gems can load the concern before the application's model autoloader is
initialized:

```ruby
require "active_storage/servable"

class MyBackend::Blob
  include ActiveStorage::Servable
end
```

Active Storage's polymorphic routes support both ordinary Ruby classes and
classes using Active Model naming. Classes with `model_name` also receive a
mapping for `model_name.name`, including overridden names. Objects implementing
`to_model` must return an object with a compatible `model_name`. These mappings
allow ordinary helpers such as `url_for(blob)` and `image_tag(message.avatar)`.

The `local_io` accessor is required for `analyze: :immediately` and variants
configured to process immediately.

`analyze` must persist the resulting metadata when called by `AnalyzeJob`.
`metadata` must return a hash, and `metadata=` must replace it without saving.
Active Storage uses these accessors to carry analysis results into pending
assignments and cached blob instances while preserving unsaved metadata edits.
Backends using the built-in analyzers and previewers must also provide their
content predicates (`image?`, `audio?`, and `video?`). Preprocessed variants use
`previewable?` to decide whether a preview is needed. A backend using
`SyncMetadataJob` must implement `sync_metadata`.

Backends using a mirror service must provide `service_metadata`, returning the
keyword arguments for the mirror's `upload`: `content_type`, `custom_metadata`,
and, when a download must be forced, `disposition` and `filename`. Apply the same
content type and disposition rules described above. `MirrorJob` uses the
configured blob class's default service, and the mirror looks up metadata with
`where(key: key).first`.

If blobs can be previewed, the blob class must provide `preview_image`, usually
by including `ActiveStorage::Attached::Model` and declaring
`has_one_attached :preview_image` on the blob class.

`attachments` must return the blob's persisted attachments and any unsaved inverse
attachments known to the backend. Shared-blob protection also depends on this
relationship.

`destroy` must protect shared blobs by raising
`ActiveStorage::ForeignKeyViolation` while attachments still reference the blob.
Normal purge paths destroy the attachment first, so single-owner purges can
still remove the blob and service object.
`purge` must rescue that foreign-key violation and keep the shared blob and file;
it must delete the service object only after metadata destruction succeeds.

When `config.active_storage.track_variants` is enabled, `destroy` must also
destroy this blob's records from `ActiveStorage.variant_record_class`, so tracked
variants and their attached image records are cleaned up with the source blob.

Attachment Class Contract
-------------------------

A custom attachment class links an owner record to a blob. It must support the
query API used by the generic attachment builder:

```ruby
class MyBackend::Attachment
  def initialize(name:, record:, blob:); end
  def self.transaction; yield; end
  def self.find_by(record_type:, record_id:, name:); end
  def self.where(attributes = {}); end

  attr_accessor :pending_upload, :immediate_variants_processed

  def id; end
  def created_at; end
  def record_type; end
  def record_id; end
  def name; end
  def blob_id; end
  def blob; end
  def blob=(blob); end
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

`blob=` must replace the cached blob and synchronize `blob_id` with its ID without
saving either record. The `blob` reader must return that assigned instance, even
when Active Storage reuses an existing attachment.

`transaction` should be a real backend transaction when the backend supports
one. If it is a no-op, a failed attachment save can leave already-saved metadata
behind unless the backend cleanup path removes it. Active Storage cleans up a
newly-created blob when generic attachment creation fails before upload.

Generic attachment persistence calls `save!` on each selected blob, including
existing direct-upload blobs. This persists identification and immediate-analysis
metadata even when assignments are replaced before saving. `save!` must write the
current attributes and raise on failure; mutation of a loaded object must not
silently update its stored attributes. Tests should save independent copies of
mutable attributes, particularly metadata, and reload fresh instances.

After rollback, blob and attachment `persisted?` and `new_record?` must reflect
the restored backend state, either through live lookups or restored instance
state. Retrying a pending assignment must recreate records removed by rollback.
The `uploaded(io:)` hook runs on a surviving saved attachment. It must upload the
IO and then run the backend's post-upload processing, once the bytes are available.

`pending_upload` is a transient flag that Active Storage sets before saving an
attachment. When it is `true`, the owner holds the upload IO and will call
`uploaded(io:)` after commit. The backend must defer post-upload processing until
that call. When it is `false`, the blob is already uploaded, including blobs
attached through signed IDs or direct uploads. Active Storage does not call
`uploaded(io:)` for those attachments. The backend must instead run the same
processing after the attachment's creation commits, provided the attachment
still exists. Do not run it after rollback or repeat it on every attachment save.

Both paths must:

* Call `blob.mirror_later` to schedule any configured mirrors.
* Call `blob.analyze_later` unless the blob is already analyzed or the effective
  analysis option is `:lazily`. Use the attachment reflection's `analyze:` option,
  falling back to `ActiveStorage.analyze`.
* For representable blobs, process the reflection's named variants according to
  each variant's `process(record)` result. Use `ActiveStorage::CreateVariantsJob`
  with the variants' transformations and `process:`: `perform_now` for
  `:immediately`, `perform_later` for `:later`, and no work for `:lazily`.

`immediate_variants_processed` is another transient flag, initially false. If
`uploaded(io:)` processes immediate variants from the local IO before uploading,
set this flag to `true` so post-upload processing skips those immediate variants.
It must still schedule variants configured for later processing.

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
destruction and return a truthy value, or raise an exception. Returning `nil` or `false`, or otherwise
halting the destroy is not supported in these dependent-destroy paths.

Attachments must delegate blob operations exposed by the attachment API, such as
`filename`, `content_type`, `download`, `url`, `variant`, and `preview`, to `blob`.

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
class contract before declaring `image`. `create_or_find_by!` must atomically
enforce uniqueness on `(blob_id, variation_digest)`, returning the existing record
when another process creates the same variant concurrently.

Collection Behavior
-------------------

For non-Active Record owners, generated `*_attachments` and `*_blobs` methods
return lightweight enumerable collection objects.

These collection objects support enumerable operations such as `each`, `to_a`,
and `any?`, along with `find_by`, `pluck`, `reload`, and `reset`.
Attachment collections also support `delete_all`. Neither collection supports
arbitrary query chaining:

```ruby
message.images_attachments.where(content_type: "image/png")
# raises ActiveStorage::QueryNotSupported
```

Query the backend class directly for backend-specific filtering:

```ruby
MyBackend::Attachment.where(record_type: "Message", record_id: message.id, name: "images")
```

Use block-based `find { |attachment| ... }` for enumerable lookup, or `find_by(id: id)`
for attribute lookup; these collections do not implement Active Record's `find(id)`.
For generic owners, `detach` removes persisted attachment rows in the current
selection, including rows carried by a pending assignment, while retaining their
blobs and files.

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
* Action Text and Action Mailbox use Active Record models that declare
  attachments. They are incompatible with custom storage classes under the
  all-or-nothing backend configuration. Load the required framework railties
  individually instead of using `rails/all`.

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
