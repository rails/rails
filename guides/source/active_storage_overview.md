**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON
<https://guides.rubyonrails.org>.**

Active Storage Overview
=======================

This guide covers how to attach files to your Active Record models.

After reading this guide, you will know:

* How to attach one or many files to a record.
* How to display attached files and how to delete them.
* How to use variants to transform images.
* How to generate an image representation of a non-image file (e.g. PDF).
* How to send file uploads directly from browsers to a storage service.
* How to set up cloud storage services to work with Active Storage.

--------------------------------------------------------------------------------

What is Active Storage?
-----------------------

Active Storage facilitates attaching files to Active Record objects and
uploading those files to your server or to a cloud storage service.

Active Storage supports image variants (e.g. resizing) and can transform and
store variants of uploaded images. Using Active Storage, you can also generate
image representations of non-image uploads like PDFs and videos, and extract
metadata.

For cloud storage services, Active Storage supports mirroring files to secondary
services to serve as a backup or to allow migration between services. Active
Storage also supports Direct Uploads, allowing files to be uploaded straight
from the client's browser to the configured cloud storage service. This avoids
routing large files through your Rails servers.

Active Storage also supports a `Disk` service which uses the local filesystem by default.

Setup and Configuration
-----------------------

Let's see Active Storage in action with an example of allowing users to upload a
profile photo. First step is to install Active Storage:

```bash
$ bin/rails active_storage:install
$ bin/rails db:migrate
```

The install command creates migrations to add the following Active Storage
specific tables to your application:

* `active_storage_blobs` - stores data about uploaded files, such as filename
  and content type.
* `active_storage_attachments` - a polymorphic join table that [connects your
  models to blobs](#attaching-files-to-records). This is a [polymorphic
  association](association_basics.html#polymorphic-associations) so if your
  model's class name changes, you will need to run a migration to update the
  underlying `record_type` column in this table to the new name.
* `active_storage_variant_records` - if [variant
  tracking](#attaching-files-to-records) is enabled, this table stores records
  for each variant that has been generated.

WARNING: If you are using UUIDs instead of integers as the primary key on your
models, you will need to set `Rails.application.config.generators { |g| g.orm
:active_record, primary_key_type: :uuid }` in a config file. This configuration
needs to be set *before* running the `active_storage:install` command.

NOTE: Since Active Storage relies on [polymorphic
associations](association_basics.html#polymorphic-associations), which store
Ruby class names in the database, you will need to manually update Active
Storage tables if you rename related Ruby classes (e.g.
`active_storage_attachments.record_type` table and column).

### Third Party Software

Various features of Active Storage depend on third-party software. Rails does
not install these by default so you will need to do so separately:

* [libvips](https://github.com/libvips/libvips) or
  [ImageMagick](https://imagemagick.org/) - for image analysis and
  transformations.
* [ffmpeg](http://ffmpeg.org/) - for video previews and ffprobe for video/audio
  analysis.
* [poppler](https://poppler.freedesktop.org/) or [muPDF](https://mupdf.com/) -
  for PDF previews.

TIP: ImageMagick is better known and more widely available. Libvips is a newer
library that runs quickly and uses little memory.

WARNING: Before you install and use third-party software, make sure you
understand the licensing implications of doing so. MuPDF, in particular, is
licensed under AGPL and requires a commercial license for some use.

### Configuring Storage Service

For local development and testing, you can use the `Disk` service to store
uploaded files. It can be configured in `config/storage.yml` as follows:

```yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

The services configured in the `config/storage.yml` file are then used in
environment specific configuration files. For example, in order to use the
`local` service above during development, we modify the
`config/environments/development.rb` file:

```ruby
# config/environments/development.rb
config.active_storage.service = :local
```

The `config/storage.yml` file is also where cloud services can be configured.
For example, assuming there is a service called `amazon` in the
`config/storage.yml` file, in order to use that service in production:

```yml
# config/environments/production.rb
config.active_storage.service = :amazon
```

You can find detailed information about [configuring cloud
services](#configuring-cloud-services) in a later section.

### Configuring Active Storage Routes

Active Storage automatically adds routes to your application for serving files.
These routes are mounted under `/rails/active_storage` by default. For example,
So when someone requests a file attachment in your app, the URL may look like
`https://example.com/rails/active_storage/blobs/redirect/eyJf.../photo.jpg`. You can see all the routes by running:

```bash
$ bin/rails routes --grep active_storage
```

To mount Active Storage routes at a different path, you can configure
`config.active_storage.routes_prefix` in `config/application.rb`. It accepts any
value supported by Rails'
[`scope`](https://api.rubyonrails.org/classes/ActionDispatch/Routing/Mapper/Scoping.html#method-i-scope) routing method:

```ruby
config.active_storage.routes_prefix = "/files"
config.active_storage.routes_prefix = { path: "/files", subdomain: "assets" }
```

Attaching Files to Records
--------------------------

Once Active Storage is installed and configured, we can upload files attached to
an Active Record model, display those files in a view, replace or remove those
files, as well as create variants.

### `has_one_attached`

The [`has_one_attached`][] method sets up a one-to-one mapping between records
and files. Each record can have one file attached to it.

For example, suppose your application has a `User` model. If you want each user
to have a profile photo, define the `User` model as follows:

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo
end
```

You can also specify an attachment when using a model generator command like
this:

```bash
$ bin/rails generate model User profile_photo:attachment
```

In order to allow a user to upload a profile photo, you can add this to the form
partial:

```erb
<%= form.file_field :profile_photo %>
```

Then in the User controller, add `:profile_photo` to the allowed params:

```ruby
class UserController < ApplicationController
  def create
    user = User.create!(user_params)
    redirect_to root_path
  end

  private
    def user_params
      params.expect(user: [:email_address, :password, :profile_photo])
    end
end
```

Now a user will be able to upload a profile photo.

Some more useful methods are [`attach`][Attached::One#attach] and
[`attached?`][Attached::One#attached?].

The `attach` method attaches a profile photo to an existing user:

```ruby
user.profile_photo.attach(params[:profile_photo])
```

The `attached?` method determines whether a particular user has a profile photo:

```ruby
user.profile_photo.attached?
```

You can override the default configured service for a specific attachment with
the `service` option:

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo, service: :amazon
end
```

[`has_one_attached`]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/Model.html#method-i-has_one_attached
[Attached::One#attach]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-attach
[Attached::One#attached?]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-attached-3F

### `has_many_attached`

The [`has_many_attached`][] method sets up a one-to-many relationship between a
record and attached files. Each record can have many files attached to it.

For example, suppose your application has a `Product` model. Each product can
have multiple images associated with it:

```ruby
class Product < ApplicationRecord
  has_many_attached :images
end
```

You can also use the model generator command like this:

```bash
$ bin/rails generate model Product images:attachments
```

The controller to create a product with multiple images looks like this:

```ruby
class ProductsController < ApplicationController
  def create
    product = Product.create!(product_params)
    redirect_to product
  end

  private
    def product_params
      params.expect(product: [ :title, :content, images: [] ])
    end
end
```

You can call [`images.attach`][Attached::Many#attach] to add new images to an
existing product:

```ruby
@product.images.attach(params[:images])
```

You can call [`images.attached?`][Attached::Many#attached?] to determine whether
a particular product has any images:

```ruby
@product.images.attached?
```

NOTE: When using `has_many_attached`, calling `images.attach(...)` adds new
attachments to the list of existing attachments. It does not replace or
overwrite existing attachments. If you want to replace existing images, you must
explicitly [purge](#removing-files) the old attachments before attaching new
ones.

You can also configure specific variants by calling the `variant` method on the
attachable object:

```ruby
class Message < ApplicationRecord
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
end
```

[`has_many_attached`]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/Model.html#method-i-has_many_attached
[Attached::Many#attach]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/Many.html#method-i-attach
[Attached::Many#attached?]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/Many.html#method-i-attached-3F

#### Adding New Attachments: Appending vs. Replacing

When working with the `has_many_attached` association, it’s important to
distinguish between calling `.attach` directly in Ruby and assigning attachments
through form parameters.

Calling `.attach` always appends new files. It never replaces existing
attachments:

```ruby
# Appends new images, previously attached images remain.
@product.images.attach(params[:new_images])
```

When a form submits `images: params`, Rails treats the submitted list as the
entire intended set of attachments for that field. If the form only includes the
newly uploaded files, Rails will interpret that as replacing the collection.

To keep existing attachments, you can use hidden form fields with the
[`signed_id`][ActiveStorage::Blob#signed_id] to re-submit each of the already
attached file:

```erb
<% @product.images.each do |image| %>
  <%= form.hidden_field :images, multiple: true, value: image.signed_id %>
<% end %>

<%= form.file_field :images, multiple: true %>
```

The above code resubmits the already-attached images back to Rails using hidden
fields, so Active Storage keeps the existing attached images when adding a new
one.

[ActiveStorage::Blob#signed_id]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-i-signed_id

### Attaching Files From Disk

Active Storage allows you to attach files that are not uploaded via a form. In
order to attach a file that you generated on disk or downloaded from a URL, you
can use the `io` and `filename` options with the `attach` method. You may also
use this method to attach fixture files during testing.

```ruby
@product.images.attach(io: File.open("/path/to/file"), filename: "product.pdf")
```

Active Storage attempts to determine a file’s content type from its data. It
falls back to the content type you provide if it can’t do that. So it's a good
practice to use the `content_type` option to specify the content type when
possible:

```ruby
@product.images.attach(io: File.open("/path/to/file"), filename: "product.pdf", content_type: "application/pdf")
```

You can also instruct Active Storage not to infer content type from the data by
using the`identify` option:

```ruby
@product.images.attach(
  io: File.open("/path/to/file"),
  filename: "product.pdf",
  content_type: "application/pdf",
  identify: false
)
```

If you don’t provide a content type and Active Storage can’t determine the
file’s content type automatically, it defaults to `application/octet-stream`.

#### Cloud Storage

For organizing files in sub-folders within your cloud storage (e.g. AWS S3
Bucket), there is a `key` option:

NOTE: The `key` parameter is treated as trusted. Using untrusted user input as the key may result in unexpected behavior.

```ruby
@product.images.attach(
  io: File.open("/path/to/file"),
  filename: "file.pdf",
  content_type: "application/pdf",
  key: "#{Rails.env}/blog_content/intuitive_filename.pdf",
  identify: false
)
```

Without the `key` specified, AWS S3 uses a random key to name your files. But
with the above `key`, the file will get saved in the folder
`[S3_BUCKET]/development/blog_content/` when you test this from your development
environment. When you use the `key` parameter, you have to ensure that the key
is unique for the upload to be successful. It is recommended to append the
filename with a random number, something like:

```ruby
def s3_file_key
  "#{Rails.env}/blog_content/intuitive_filename-#{SecureRandom.uuid}.pdf"
end
```

```ruby
@product.images.attach(
  io: File.open("/path/to/file"),
  filename: "product.pdf",
  content_type: "application/pdf",
  key: s3_file_key,
  identify: false
)
```

### Form Validation

Attachments aren't sent to the storage service until a successful `save` on the
associated record. This means that if a form submission fails validation, any
new attachments will be lost and must be uploaded again. [Direct
uploads](#direct-uploads) work differently. They are stored before the form is
submitted, so they retain uploads even when validation fails:

```erb
<%= form.hidden_field :profile_photo, value: @user.profile_photo.signed_id if @user.profile_photo.attached? %>
<%= form.file_field :profile_photo, direct_upload: true %>
```

Querying Attached Files
-----------------------

Since Active Storage attachments are Active Record associations, you can use the
usual [query methods](active_record_querying.html) to look up records associated
with attachments in the Active Storage related tables.

### `has_one_attached`

When you declare `has_one_attached :profile_photo`, Rails automatically sets up
two associations behind the scenes: a `has_one` association called
`profile_photo_attachment`, which points to the `active_storage_attachments`
table, and a `has_one :through` association called `profile_photo_blob`, which
points to the `active_storage_blobs` table through the attachment record.

Because these associations behave like normal Active Record relations, you can
query them. For example, the following query joins the `users` table to the blob
record and filters for all users whose profile_photo has a PNG content type:

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo
end

# Query users whose profile_photo is a PNG
users = User.joins(:profile_photo_blob).where(
  active_storage_blobs: { content_type: "image/png" }
)
```

### `has_many_attached`

Similarly, when you use `has_many_attached`, Rails defines two associations: a
`has_many` association named `<name>_attachments`, which represents the join
records in the `active_storage_attachments` table, and a `has_many :through`
association named `<name>_blobs`, which gives access to the corresponding rows
in `active_storage_blobs` table.

Because the `_blobs` association provides a normal relational join, you can
query it directly to filter records based on metadata stored in the blob. For
example, the following code retrieves all `Product` records whose attached
images are videos with an MP4 format:

```ruby
class Product < ApplicationRecord
  has_many_attached :images
end

products = Product.joins(:images_blobs).where(
  active_storage_blobs: { content_type: "video/mp4" }
)
```

This query executes against the `active_storage_blobs` table rather than the
attachment records themselves, since the join created by `joins(:images_blobs)`
operates on the blob side of the association. You can combine such blob-based
filters with additional scope conditions in the same way you would with any
standard Active Record query.

Serving Files
-------------

Active Storage can serve files in two different ways: redirect mode and proxy
mode. Both modes use built-in controllers to deliver blobs and
[representations](#file-representations), but they differ in how the file
ultimately reaches the browser.

WARNING: All Active Storage controllers are publicly accessible by default.
Anyone who knows the URL can access the file, even if the rest of your
application requires authentication. If your files require access control
consider implementing [Authenticated Controllers](#authenticated-controllers).

### Redirect Mode

To generate a permanent URL for a blob, you can pass the attachment or the blob
to the [`url_for`][ActionView::RoutingUrlFor#url_for] view helper. This
generates a URL with the blob's [`signed_id`][ActiveStorage::Blob#signed_id]
which points to the blob's
[`RedirectController`][`ActiveStorage::Blobs::RedirectController`]

```ruby
url_for(user.profile_photo)
# => https://www.example.com/rails/active_storage/blobs/redirect/:signed_id/my-profile-photo.png
```

The `RedirectController` does not serve the file itself. Instead, it takes the
permanent, signed Rails URL and issues a redirect to a short-lived service URL
(e.g. an expiring S3 URL). This indirection decouples your application’s public
URLs from the underlying storage service and enables features such as mirroring
attachments across multiple services for high-availability. The redirect
response is cached by the browser for 5 minutes by default.

To create a download link, use the `rails_blob_{path|url}` helpers. These
helpers generate the same permanent Rails URL but allow you to specify the file
[Content-Disposition Header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Disposition).

```ruby
rails_blob_path(user.profile_photo, disposition: "attachment")
```

WARNING: To prevent XSS attacks, Active Storage forces the Content-Disposition
header to "attachment" for certain file types. To change this behavior see the
available configuration options in [Configuring Rails
Applications](configuring.html#configuring-active-storage).

If you need to create a link from outside of controller/view context, for
background jobs for example, you can access the `rails_blob_path` like this:

```ruby
Rails.application.routes.url_helpers.rails_blob_path(user.profile_photo, only_path: true)
```

[ActionView::RoutingUrlFor#url_for]:
https://api.rubyonrails.org/classes/ActionView/RoutingUrlFor.html#method-i-url_for
[ActiveStorage::Blob#signed_id]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-i-signed_id

### Proxy Mode

In proxy mode, Rails retrieves the file from the storage service and then
proxies it back to the client. Instead of sending a redirect, Rails responds
with the file data directly from your application server.

The default configuration mode is `rails_storage_redirect`. You can configure
Active Storage to use proxying like this:

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

Or if you want to explicitly proxy specific attachments there are URL helpers
you can use in the form of `rails_storage_proxy_path` and
`rails_storage_proxy_url`.

```erb
<%= image_tag rails_storage_proxy_path(@user.profile_photo) %>
```

#### Putting a CDN in Front of Active Storage

To use a CDN in front of Active Storage attachments, you must generate URLs
using proxy mode. In proxy mode, files are served through your application
rather than redirected to the underlying storage service. This allows the CDN to
cache the file without additional configuration, because the default Active
Storage proxy controllers send HTTP headers instructing intermediaries
(including CDNs) to cache the response.

When using a CDN, you will need to ensure that the generated URLs use the CDN
host instead of your application host. There are multiple ways to achieve this,
but in general it involves tweaking your `config/routes.rb` file so that you can
generate the proper URLs for the attachments and their variations. As an
example, you could add this:

```ruby
# config/routes.rb
direct :cdn_image do |model, options|
  expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

  if model.respond_to?(:signed_id)
    route_for(
      :rails_service_blob_proxy,
      model.signed_id(expires_in: expires_in),
      model.filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  else
    signed_blob_id = model.blob.signed_id(expires_in: expires_in)
    variation_key  = model.variation.key
    filename       = model.blob.filename

    route_for(
      :rails_blob_representation_proxy,
      signed_blob_id,
      variation_key,
      filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  end
end
```

and then generate routes like this:

```erb
<%= cdn_image_url(user.profile_photo.variant(resize_to_limit: [128, 128])) %>
```

### Authenticated Controllers

By default, all Active Storage controllers are publicly accessible. The URLs
they generate contain a blob’s [signed_id][ActiveStorage::Blob#signed_id], which
is hard to guess but permanent. Anyone who knows the URL can access the file,
even if the rest of your application requires authentication. Also, the
`before_action`s in your own controllers (such as requiring a logged-in user) do
not apply to Active Storage’s built-in controllers.

If your files require stricter access control, such as “a user may only view
their own files”, you can replace the built-in controllers with your own
authenticated controllers. These controllers should wrap the behavior of the
following built-in controllers but apply your own authorization logic before
serving the file :

* [`ActiveStorage::Blobs::RedirectController`][]
* [`ActiveStorage::Blobs::ProxyController`][]
* [`ActiveStorage::Representations::RedirectController`][]
* [`ActiveStorage::Representations::ProxyController`][]

As an example, to only allow an account to access their own logo you could do
the following:

```ruby
# config/routes.rb
resource :account do
  resource :logo
end
```

```ruby
# app/controllers/logos_controller.rb
class LogosController < ApplicationController
  # include Authentication via ApplicationController

  def show
    redirect_to Current.user.account.logo.url
  end
end
```

```erb
<%= image_tag account_logo_path %>
```

And finally, disable the Active Storage default routes with:

```ruby
config.active_storage.draw_routes = false
```

This ensures that blobs and variants cannot be accessed through the built-in
public controllers, and can only be served through your own authenticated
routing and authorization logic.

[`ActiveStorage::Blobs::RedirectController`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blobs/RedirectController.html
[`ActiveStorage::Blobs::ProxyController`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blobs/ProxyController.html
[`ActiveStorage::Representations::RedirectController`]:
https://api.rubyonrails.org/classes/ActiveStorage/Representations/RedirectController.html
[`ActiveStorage::Representations::ProxyController`]:
https://api.rubyonrails.org/classes/ActiveStorage/Representations/ProxyController.html

### Expiring URLs

By default, the URLs generated by Active Storage's redirect and proxy
controllers never expire but there is an `expires_in` option to limit how long URLs remain valid.

To set an expiration on a per-URL basis, pass `expires_in` when generating the
URL:

```ruby
rails_storage_redirect_url(blob, expires_in: 1.minute)
rails_storage_proxy_url(@user.profile_photo, expires_in: 1.hour)
```

To set a default expiration for all Active Storage controller URLs in your application:

```ruby
config.active_storage.urls_expire_in = 1.day
```

Note that expiring *controller URLs* is distinct from expiring *service URLs*
(the short-lived signed URLs that redirect controllers use to forward requests
to the underlying storage service such as S3). Service URLs default to expiring
in 5 minutes and can be configured separately:

```ruby
config.active_storage.service_urls_expire_in = 10.minutes
```

WARNING: The `expires_in` option is not a substitute for authenticated access
control. An expired URL simply stops working, but a URL shared before expiration
remains accessible for its full lifetime. For true access control, use
Authenticated Controllers.

Downloading Files
-----------------

Sometimes you need to process a file after it’s uploaded. For example, to
convert it to a different format. You can use the [`download`][Blob#download]
method to read the file's binary data (i.e. blob) into memory:

```ruby
binary = user.profile_photo.download
```

You can also download a file's blob to local disk so an external program (e.g. a
virus scanner or media transcoder) can operate on it. In the example below, the
blob's [`open`][Blob#open] method saves the file to a tempfile on disk and then
yields the file to the block:

```ruby
product.images.open do |file|
  system "/path/to/virus/scanner", file.path
  # ...
end
```

NOTE: Active Storage attachments are not fully available until the record’s
transaction has committed. This means methods like `download` and `open` cannot
be used reliably inside an `after_create` callback because the blob is not
persisted yet. Use `after_create_commit` if you need to process the uploaded
file immediately after creation.

[Blob#download]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-i-download
[Blob#open]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-i-open

Removing Files
--------------

Active Storage makes it possible to remove files from your application when they are no longer needed, whether that's when a user replaces their profile photo, deletes a product image, or as part of routine cleanup of orphaned uploads.

### Removing Attachments From a Model

To remove an attachment from a model, call [`purge`][Attached::One#purge] on the
attachment. If your application is set up to use Active Job, removal can be done
in the background as well by calling [`purge_later`][Attached::One#purge_later].
Purging destroys the attachment (`ActiveStorage::Attachment`) record. If the blob has no more attachments, the blob (`ActiveStorage::Blob`) record gets destroyed as well and the file is deleted from the storage service.

```ruby
# Removes the profile_photo
user.profile_photo.purge

# Removes the file asynchronously with Active Job.
user.profile_photo.purge_later
```

[Attached::One#purge]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-purge
[Attached::One#purge_later]:
https://api.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-purge_later

In order to remove a single file from a model with `has_many_attached`, you first find the record and then use `purge` or `purge_later`:

```ruby
product.images.find(image_id).purge
product.images.find(image_id).purge_later
```

### Purging Unattached Uploads and `detach`

There are cases where a file is uploaded but never attached to a record. This
can happen when using [Direct Uploads](#direct-uploads). You can query for
unattached records using the [unattached scope](https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-c-unattached). Below is an
example using a [custom rake task](command_line.html#custom-rake-tasks) to remove unattached files:

```ruby
namespace :active_storage do
  desc "Purges unattached Active Storage blobs. Run regularly."
  task purge_unattached: :environment do
    ActiveStorage::Blob.unattached.where(created_at: ..2.days.ago).find_each(&:purge_later)
  end
end
```

WARNING: The query generated by `ActiveStorage::Blob.unattached` can be slow and
potentially disruptive on applications with larger databases.

There is also a [`detach`](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-detach) method, which deletes the associated attachments but leaves the blobs in place. This intentionally orphans the blob and leaves the file on the storage service.

```ruby
user.profile_photo.detach
```

This can be useful if you want to disassociate a file from a record without deleting it from storage, in case the blob is referenced elsewhere. Note that you can later find such orphaned blobs using the `unattached` scope if needed.

Analyzing Files For Metadata
----------------------------

Active Storage analyzes files to extract metadata like image dimensions, video
duration, and audio bit rate.  Once a file has been analyzed, the metadata is
stored in the `active_storage_blobs` table and can be viewed with the
[`metadata`][] method:

```irb
> user.profile_photo.metadata
=> {"identified" => true, "width" => 112, "height" => 243, "created_at" => "2026-04-05T00:11:48+02:00", "analyzed" => true}
```

Analyzed files will store additional information in the metadata hash, including
`analyzed: true`. You can check whether a blob has been analyzed by calling the
[`analyzed?`][] method on it.

```irb
> user.profile_photo.analyzed?
=> true
```

Image analysis provides `width` and `height` attributes. Video analysis provides
these, as well as `duration`, `angle`, `display_aspect_ratio`, and `video` and
`audio` booleans to indicate the presence of those channels. Audio analysis
provides `duration` and `bit_rate` attributes.

### Controlling When Analysis is Performed

You can control *when* metadata analysis is performed by using the `analyze`
option when defining attachments with `has_one_attached` or `has_many_attached`.
The default value of this option is `immediately`, but it can be set to `later`
or `lazily`:

```ruby
class User < ApplicationRecord
  # Analyze before validation (default value)
  has_one_attached :avatar, analyze: :immediately

  # Analyze after upload from local IO or via background job for direct uploads
  has_one_attached :document, analyze: :later

  # Skip automatic analysis - analyze on-demand when metadata is accessed
  has_many_attached :files, analyze: :lazily
end
```

NOTE: Attachments with `process: :immediately` variants automatically analyze
immediately to ensure metadata is available before processing.

You can set the application level default for the `analyze` option in your Rails
application configuration as well:

```ruby
# config/application.rb
config.active_storage.analyze = :later
```

### Validating Attachment Metadata

Since attachments are analyzed immediately by default, metadata is available for
model validations. For example, it's possible to validate that the uploaded
profile photo has certain dimensions:

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo

  validate :validate_profile_photo_size, if: -> { profile_photo.attached? }

  private
    def validate_profile_photo_size
      if profile_photo.metadata[:width] < 200 || profile_photo.metadata[:height] < 200
        errors.add(:profile_photo, "must be at least 200x200 pixels")
      end
    end
end
```

NOTE: Since [Direct uploads](#direct-uploads) bypass the server, files aren't
locally available for analysis. In this case, `:immediately` falls back to
`:later`, analyzing via background job after upload completes. So model
validations using metadata aren't possible. You can validate on the client side
using JavaScript instead.

[`metadata`][]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob.html#method-i-metadata
[`analyzed?`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob/Analyzable.html#method-i-analyzed-3F

Displaying Images, Videos, and PDFs
-----------------------------------

Active Storage supports displaying a variety of files. You can use variants for
image files and previews for other files such as video or PDF. There is also a
concept for *representation*, which displays either a variant or preview
depending on the file.

### Image Variants

You can configure specific variants for attachments by calling the
[`variant`](https://api.rubyonrails.org/classes/ActiveStorage/Variant.html)
method on an attachable object:

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
end
```

You can call `profile_photo.variant(:thumb)` in a view to get a thumb variant of
a profile photo:

```erb
<%= image_tag user.profile_photo.variant(:thumb) %>
```

There is a `process` option that can be used to control when variants are
generated. The default value for the `process` option is `lazily`. The other two
values are `later` and `immediately`.

* `:lazily` (default) - variants are created on the fly when first requested
* `:later` - variants are created in a background job after the attachment is
  saved
* `:immediately` - variants are created synchronously when the attachment is
  created

```ruby
class User < ApplicationRecord
  has_one_attached :profile_photo do |attachable|
    # Create immediately when the profile_photo is attached
    attachable.variant :thumb, resize_to_limit: [100, 100], process: :immediately

    # Create in a background job after attachment
    attachable.variant :medium, resize_to_limit: [300, 300], process: :later

    # Create on demand when first requested (default)
    attachable.variant :large, resize_to_limit: [800, 800], process: :lazily
  end
end
```

So, for example, if you know in advance that your variants will be accessed, you
can use the `process: :later` option (with both `has_one_attached` and
`has_many_attached`) to specify that Rails should generate them ahead of time
(and not lazily).

WARNING: It should be considered unsafe to provide arbitrary user supplied
transformations or parameters to variant processors. This can potentially enable
command injection vulnerabilities in your app. It is also recommended to
implement a strict [ImageMagick security
policy](https://imagemagick.org/script/security-policy.php) when MiniMagick is
the variant processor of choice. With ruby-vips, you can
[block untrusted formats][https://www.libvips.org/2022/05/28/What's-new-in-8.13.html#blocking-of-unfuzzed-loaders]
by setting `VIPS_BLOCK_UNTRUSTED` environment variable or calling
`Vips.block_untrusted(true)` in an initializer.

### Non-image Previews

Some non-image files can be previewed: that is, they can be presented as images.
For example, a video file can be previewed by extracting its first frame. Out of
the box, Active Storage supports previewing videos and PDF documents. To create
a link to a lazily-generated preview, use the attachment's [`preview`][] method:

```erb
<%= image_tag message.video.preview(resize_to_limit: [100, 100]) %>
```

To add support for another format, add your own previewer. See the
[`ActiveStorage::Preview`][] documentation for more information.

[`preview`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob/Representable.html#method-i-preview
[`ActiveStorage::Preview`]:
https://api.rubyonrails.org/classes/ActiveStorage/Preview.html

### File Representations

Active Storage supports displaying a variety of files. You can call
[`representation`][] on an attachment to display an image variant, or a preview
of a video or PDF.

Some file formats can't be previewed by Active Storage out of the box (e.g. Word
documents), so it's a good idea to call the boolean method [`representable?`]
first. In the case where `representable?` returns `false`, you can directly
[link to](#serving-files) the file instead, as shown in the example below:

```erb
<ul>
  <% @task.files.each do |file| %>
    <li>
      <% if file.representable? %>
        <%= image_tag file.representation(resize_to_limit: [100, 100]) %>
      <% else %>
        <%= link_to rails_blob_path(file, disposition: "attachment") do %>
          <%= image_tag "placeholder.png", alt: "Download file" %>
        <% end %>
      <% end %>
    </li>
  <% end %>
</ul>
```

Internally, `representation` calls `variant` for images, and `preview` for
previewable files. You can also call these methods directly.

[`representable?`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob/Representable.html#method-i-representable-3F
[`representation`]:
https://api.rubyonrails.org/classes/ActiveStorage/Blob/Representable.html#method-i-representation

### How Lazy Processing Works

By default, Active Storage processes representations lazily. This means the
image is transformed in a separate request when needed, avoiding any work during
the initial page render.

```ruby
image_tag file.representation(resize_to_limit: [100, 100])
```

The above example will generate an `<img>` tag with the `src` attribute pointing
to the [`ActiveStorage::Representations::RedirectController`][]. When the
browser makes a request to that controller, it will perform the following:

1. Process the file and upload the processed file if necessary.
2. Return a `302` redirect to the file either to
  * the remote service (e.g., S3).
  * or `ActiveStorage::Blobs::ProxyController` which will return the file
    contents if [proxy mode](#proxy-mode) is enabled.

Loading the file lazily allows features like [single use URLs](#public-access)
to work without slowing down your initial page loads.

This works fine for most cases but if you need to generate URLs for images
immediately, you can call `.processed.url`:

```ruby
image_tag file.representation(resize_to_limit: [100, 100]).processed.url
```

The Active Storage variant tracker stores a record in the database if the
requested representation has been processed before. So the above code will only
make an API call to the remote service (e.g. S3) once. After that, the variant
will be stored and used on subsequent requests.

However, if you're rendering many images on a page, the example above can cause
an [N+1 query problem](active_record_querying.html#n-1-queries-problem). Each
call to `file.representation(...)` will look up its variant record individually,
resulting in one query per image. To avoid these extra queries, you can preload
variant records using the named scope, [`with_all_variant_records`][] on
`ActiveStorage::Attachment`.

```ruby
product.images.with_all_variant_records.each do |file|
  image_tag file.representation(resize_to_limit: [100, 100]).processed.url
end
```

The variant tracker runs automatically. It is enabled by default but can be
disabled using [`config.active_storage.track_variants`][].

[`config.active_storage.track_variants`]:
configuring.html#config-active-storage-track-variants
[`ActiveStorage::Representations::RedirectController`]:
https://api.rubyonrails.org/classes/ActiveStorage/Representations/RedirectController.html
[`with_all_variant_records`]:
https://api.rubyonrails.org/classes/ActiveStorage/Attachment.html#method-c-with_all_variant_records

Configuring Cloud Services
------------------------

Active Storage supports multiple cloud and local storage backends and each
environment in your application can use a different one. All service
configurations live in `config/storage.yml` file, where you define the
connection details for each service your app might use. Once declared, services
can be selected per-environment in `config/environments/*.rb` files.

### Define Storage Services

For each service your application uses, provide a name and the necessary
configuration details. The example below declares three services named `local`,
`test`, and `amazon`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

# Use bin/rails credentials:edit to set the AWS secrets
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  bucket: your_own_bucket-<%= Rails.env %>
  region: "" # e.g. 'us-east-1'
```

You can tell Active Storage which service to use by setting
`Rails.application.config.active_storage.service`. Because each environment will
likely use a different service, it is recommended to do this on a
per-environment basis. To use the disk service from the previous example in the
development environment, you would add the following to
`config/environments/development.rb`:

```ruby
config.active_storage.service = :local
```

To use the S3 service in production, you would add the following to
`config/environments/production.rb`:

```ruby
config.active_storage.service = :amazon
```

To use the test service when testing, you would add the following to
`config/environments/test.rb`:

```ruby
config.active_storage.service = :test
```

NOTE: Configuration files that are environment-specific will take precedence: in
production, for example, the `config/storage/production.yml` file will take
precedence over the `config/storage.yml` file.

It’s a good practice to include `Rails.env` in your bucket names (i.e. storage
containers). This helps prevent accidental cross-environment access or data
loss, such as overwriting production data while working in development.

```yaml
amazon:
  service: S3
  # ...
  bucket: your_own_bucket-<%= Rails.env %>

google:
  service: GCS
  # ...
  bucket: your_own_bucket-<%= Rails.env %>
```

Next, let's look at how to configure Active Storage's built-in service adapters
(e.g. `Disk` and `S3`). A service adapter is the component that knows how to
store, retrieve, and delete files on a particular backend.

### Disk Service

Configuring a Disk service is straightforward, as we have seen in
`config/storage.yml`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

### S3 Service (Amazon S3 and S3-compatible APIs)

Active Storage’s built-in S3 service adapter relies on the official AWS SDK to
communicate with Amazon S3 (or any S3-compatible service). Rails does not bundle
the AWS SDK by default, so you must add the `aws-sdk-s3` gem to your
application’s Gemfile:

```ruby
gem "aws-sdk-s3", require: false
```

The `require: false` option avoids loading the SDK automatically. Active Storage
will load it only when the S3 service is used, keeping application boot time and
memory usage lower.

To connect to Amazon S3, you can configure an `S3` service in
`config/storage.yml`:

```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: "" # e.g. 'us-east-1'
  bucket: your_own_bucket-<%= Rails.env %>
```

NOTE: The above configuration assumes that AWS secrets are stored using
`bin/rails credentials:edit` with the appropriate keys. See the [Security
Guide](security.html#custom-credentials) for more.

There are other optional configurations as well - such as HTTP timeouts, retry
limits, and upload options - that can be included:

```yaml
amazon:
  # ...
  http_open_timeout: 0
  http_read_timeout: 0
  retry_limit: 0
  upload:
    server_side_encryption: "" # 'aws:kms' or 'AES256'
    cache_control: "private, max-age=<%= 1.day.to_i %>"
```

The `cache_control` option adds the `Cache-Control` header to uploaded files, so
that an image downloaded from the server won't get loaded again by the browser
if it's present in the browser's cache and not expired.

TIP: Set sensible client HTTP timeouts and retry limits for your application. In
certain failure scenarios, the default AWS client configuration may cause
connections to be held for up to several minutes and lead to request queuing.

NOTE: If you want to use environment variables, standard SDK configuration
files, profiles, IAM instance profiles or task roles, you can omit the
`access_key_id`, `secret_access_key`, and `region` keys in the example above.
The S3 Service supports all of the authentication options described in the [AWS
SDK
documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html).

You can also connect to an S3-compatible object storage API such as DigitalOcean
Spaces by providing an `endpoint`:

```yaml
digitalocean:
  service: S3
  endpoint: https://nyc3.digitaloceanspaces.com
  access_key_id: <%= Rails.application.credentials.dig(:digitalocean, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:digitalocean, :secret_access_key) %>
  # ...and other options
```

NOTE: The core features of Active Storage require the following permissions:
`s3:ListBucket`, `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject`. [Public
access](#public-access) additionally requires `s3:PutObjectAcl`. If you have
additional upload options configured such as setting ACLs then additional
permissions may be required.

There are many other options available. You can see them in the [AWS S3
Client](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#initialize-instance_method)
documentation.

### Google Cloud Storage Service

You'll need  to add the
[`google-cloud-storage`](https://github.com/GoogleCloudPlatform/google-cloud-ruby/tree/main/google-cloud-storage)
gem to your `Gemfile` to use the `GCS` service for Active Storage:

```ruby
gem "google-cloud-storage", "~> 1.11", require: false
```

The `require: false` option avoids loading the gem automatically. Active Storage
will load it only when the GCS service is used, keeping application boot time
and memory usage lower.

Then you can declare a Google Cloud Storage service in `config/storage.yml`:

```yaml
google:
  service: GCS
  credentials: <%= Rails.root.join("path/to/keyfile.json") %>
  project: ""
  bucket: your_own_bucket-<%= Rails.env %>
```

You can also provide a Hash of credentials instead of a keyfile path, and
optionally provide a Cache-Control header:

```yaml
# Use bin/rails credentials:edit to set the GCS secrets (as gcs:private_key_id|private_key)
google:
  service: GCS
  credentials:
    type: "service_account"
    project_id: ""
    private_key_id: <%= Rails.application.credentials.dig(:gcs, :private_key_id) %>
    private_key: <%= Rails.application.credentials.dig(:gcs, :private_key).dump %>
    client_email: ""
    client_id: ""
    auth_uri: "https://accounts.google.com/o/oauth2/auth"
    token_uri: "https://accounts.google.com/o/oauth2/token"
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
    client_x509_cert_url: ""
  project: ""
  bucket: your_own_bucket-<%= Rails.env %>
  cache_control: "public, max-age=3600"
```

You can optionally use
[IAM](https://cloud.google.com/storage/docs/access-control/signed-urls#signing-iam)
instead of the `credentials` when signing URLs. This is useful if you are
authenticating your GKE (Google Kubernetes Engine) applications with Workload
Identity, see [this Google Cloud blog
post](https://cloud.google.com/blog/products/containers-kubernetes/introducing-workload-identity-better-authentication-for-your-gke-applications)
for more information.

```yaml
google:
  service: GCS
  # ...
  iam: true
```

You can specify a GSA (Google Service Account) when signing URLs. When using
IAM, the [metadata
server](https://cloud.google.com/compute/docs/storing-retrieving-metadata) will
be contacted to get the GSA email, but this metadata server is not always
present (e.g. local tests) and you may wish to use a non-default GSA.

```yaml
google:
  service: GCS
  # ...
  iam: true
  gsa_email: "foobar@baz.iam.gserviceaccount.com"
```

### Mirror Service

Active Storage lets you keep multiple services in sync by defining a mirror
service. A mirror service replicates uploads and deletes across two or more
subordinate services, ensuring that files exist in multiple locations.

Mirror services are primarily intended for temporary use during migrations
between storage backends. The typical workflow is:

1. Start mirroring uploads to a new service alongside the existing one.
2. Copy any pre-existing files from the old service to the new one.
3. Switch entirely to the new service once all files are replicated.

NOTE: Mirroring is not atomic. It’s possible for an upload to succeed on the
primary service but fail on one or more mirrors. Before switching fully to the
new service, ensure that all files have been successfully copied.

In order to define a `Mirror` service, first define each service you want to
mirror as usual. Then, reference them by name in the `Mirror` service
configuration:

```yaml
s3_west_coast:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: "" # e.g. 'us-west-1'
  bucket: your_own_bucket-<%= Rails.env %>

s3_east_coast:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: "" # e.g. 'us-east-1'
  bucket: your_own_bucket-<%= Rails.env %>

production:
  service: Mirror
  primary: s3_east_coast
  mirrors:
    - s3_west_coast
```

While all secondary services receive uploads, downloads are always handled by
the primary service.

Mirror services are compatible with [direct uploads](#direct-uploads). New files
are directly uploaded to the primary service. When a directly-uploaded file is
attached to a record, a background job is enqueued to copy it to the secondary
services.

### Public Access

By default, Active Storage assumes private access to services. This means
generating signed, single-use URLs for blobs. If you'd rather make blobs
publicly accessible, specify `public: true` in your app's `config/storage.yml`:

```yaml
gcs: &gcs
  service: GCS
  project: ""

private_gcs:
  <<: *gcs
  credentials: <%= Rails.root.join("path/to/private_key.json") %>
  bucket: your_own_bucket-<%= Rails.env %>

public_gcs:
  <<: *gcs
  credentials: <%= Rails.root.join("path/to/public_key.json") %>
  bucket: your_own_bucket-<%= Rails.env %>
  public: true
```

Make sure your buckets are properly configured for public access. See docs on
how to enable public read permissions for [Amazon
S3](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/block-public-access-bucket.html)
and [Google Cloud
Storage](https://cloud.google.com/storage/docs/access-control/making-data-public#buckets)
storage services. Amazon S3 additionally requires that you have the
`s3:PutObjectAcl` permission.

When converting an existing application to use `public: true`, make sure to
update every individual file in the bucket to be publicly-readable before
switching over.

### Implementing Other Cloud Services

If you need to support a cloud service other than the ones covered above, you
can implement your custom service by extending
[`ActiveStorage::Service`](https://api.rubyonrails.org/classes/ActiveStorage/Service.html)
and implementing the methods necessary to upload and download files to the
cloud.

Direct Uploads
--------------

By default, files uploaded through Active Storage are sent to your Rails server
first, then forwarded to the configured storage service. Direct uploads bypass
the Rails server entirely, sending files straight from the browser to the
storage service. Direct uploads provide improved performance as large files do
not have to pass through your Rails server.

Direct uploads integrate seamlessly with Active Storage’s attachments and
variants, allowing you to use the same models, validations, and background
processing workflows as standard uploads.

Active Storage, with its included JavaScript library, supports uploading
directly from the client to the cloud.

### Setup JavaScript Library

In order to start using direct uploads, you'll need to use the JavaScript
Library included with Active Storage. The library handles:

* Initiating uploads to the configured service (e.g., S3, GCS, Azure).
* Tracking upload progress and reporting it to the user.
* Updating form inputs with the necessary signed IDs so that Rails can associate
  the uploaded file with the model when the form is submitted.

To use direct uploads, you'll need to include the library in your application’s
JavaScript bundle and enable the `direct_upload: true` option on your file input
fields. This allows Rails and the storage service to coordinate securely using
signed IDs, without requiring extra backend configuration.

There are several ways to include the Active Storage JavaScript library in your
application:

#### `javascript_include_tag`

Use `javascript_include_tag` to include the library in your HTML
without bundling through the asset pipeline. Autostart is enabled
automatically:

```erb
<%= javascript_include_tag "activestorage" %>
```

#### Importmaps

Use Importmap (ESM) to pin the library in `config/importmap.rb`:

```ruby
pin "@rails/activestorage", to: "activestorage.esm.js"
```

Then import and start it in your HTML:

```html
<script type="module-shim">
  import * as ActiveStorage from "@rails/activestorage"
  ActiveStorage.start()
</script>
```

#### npm package

Install the npm package via npm/yarn and import it in your JavaScript
bundle:

```js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

All of these approaches provide the same functionality; choose the one that
matches your application’s JavaScript setup.

### Enabling Direct Uploads on the Input

Next step is to set the `direct_upload: true` option in your [`file_field`
helper](form_helpers.html#uploading-files) to automatically annotate the input
field with the direct upload URL via `data-direct-upload-url` attribute.

```erb
<%= form.file_field :attachments, multiple: true, direct_upload: true %>
```

Or, if you aren't using a `FormBuilder`, add the data attribute directly:

```erb
<input type="file" data-direct-upload-url="<%= rails_direct_uploads_url %>" />
```

Lastly, You'll need to configure CORS on third-party storage services to allow
direct upload requests.

### Cross-Origin Resource Sharing (CORS) Configuration

To make direct uploads to a third-party service work, you’ll need to configure
the service to allow cross-origin requests from your app. Consult the CORS
documentation for your service:

* [S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enabling-cors-examples.html)
* [Google Cloud Storage](https://cloud.google.com/storage/docs/configuring-cors)

Take care to allow:

* All origins from which your app is accessed
* The `PUT` request method
* The following headers:
  * `Content-Type`
  * `Content-MD5`
  * `Content-Disposition`
  * `Cache-Control` (for GCS, only if `cache_control` is set)

No CORS configuration is required for the Disk service since it shares your
app’s origin.

#### Example: S3 CORS Configuration

```json
[
  {
    "AllowedHeaders": [
      "Content-Type",
      "Content-MD5",
      "Content-Disposition"
    ],
    "AllowedMethods": [
      "PUT"
    ],
    "AllowedOrigins": [
      "https://www.example.com"
    ],
    "MaxAgeSeconds": 3600
  }
]
```

#### Example: Google Cloud Storage CORS Configuration

```json
[
  {
    "origin": ["https://www.example.com"],
    "method": ["PUT"],
    "responseHeader": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "maxAgeSeconds": 3600
  }
]
```

### Direct Upload JavaScript Events

The JavaScript library supports events that can be used for the upload form:

| Event name | Event target | Event data (`event.detail`) | Description |
| --- | --- | --- | --- |
| `direct-uploads:start` | `<form>` | None | A form containing files for direct upload fields was submitted. |
| `direct-upload:initialize` | `<input>` | `{id, file}` | Dispatched for every file after form submission. |
| `direct-upload:start` | `<input>` | `{id, file}` | A direct upload is starting. |
| `direct-upload:before-blob-request` | `<input>` | `{id, file, xhr}` | Before making a request to your application for direct upload metadata. |
| `direct-upload:before-storage-request` | `<input>` | `{id, file, xhr}` | Before making a request to store a file. |
| `direct-upload:progress` | `<input>` | `{id, file, progress}` | As requests to store files progress. |
| `direct-upload:error` | `<input>` | `{id, file, error}` | An error occurred. An `alert` will display unless this event is canceled. |
| `direct-upload:end` | `<input>` | `{id, file}` | A direct upload has ended. |
| `direct-uploads:end` | `<form>` | None | All direct uploads have ended. |

### Example

You can use these events to show the progress of an upload.

![direct-uploads](https://user-images.githubusercontent.com/5355/28694528-16e69d0c-72f8-11e7-91a7-c0b8cfc90391.gif)

To show the progress of the uploaded files in a form add the following
javascript:

```js
// app/javascript/direct_uploads.js
addEventListener("direct-upload:initialize", event => {
  const { target, detail } = event
  const { id, file } = detail
  target.insertAdjacentHTML("beforebegin", `
    <div id="direct-upload-${id}" class="direct-upload direct-upload--pending">
      <div id="direct-upload-progress-${id}" class="direct-upload__progress" style="width: 0%"></div>
      <span class="direct-upload__filename"></span>
    </div>
  `)
  target.previousElementSibling.querySelector(`.direct-upload__filename`).textContent = file.name
})

addEventListener("direct-upload:start", event => {
  const { id } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.remove("direct-upload--pending")
})

addEventListener("direct-upload:progress", event => {
  const { id, progress } = event.detail
  const progressElement = document.getElementById(`direct-upload-progress-${id}`)
  progressElement.style.width = `${progress}%`
})

addEventListener("direct-upload:error", event => {
  event.preventDefault()
  const { id, error } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.add("direct-upload--error")
  element.setAttribute("title", error)
})

addEventListener("direct-upload:end", event => {
  const { id } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.add("direct-upload--complete")
})
```

Add CSS to style the progress of the uploaded files:

```css
/* app/assets/stylesheets/direct_uploads.css */
.direct-upload {
  display: inline-block;
  position: relative;
  padding: 2px 4px;
  margin: 0 3px 3px 0;
  border: 1px solid rgba(0, 0, 0, 0.3);
  border-radius: 3px;
  font-size: 11px;
  line-height: 13px;
}

.direct-upload--pending {
  opacity: 0.6;
}

.direct-upload__progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  opacity: 0.2;
  background: #0076ff;
  transition: width 120ms ease-out, opacity 60ms 60ms ease-in;
  transform: translate3d(0, 0, 0);
}

.direct-upload--complete .direct-upload__progress {
  opacity: 0.4;
}

.direct-upload--error {
  border-color: red;
}

input[type=file][data-direct-upload-url][disabled] {
  display: none;
}
```

### Custom Drag and Drop Solutions

You can use the `DirectUpload` class for this purpose as well. Upon receiving a
file from your library of choice, instantiate a DirectUpload and call its create
method. Create takes a callback to invoke when the upload completes.

```js
// app/javascript/drag_and_drop_uploads.js
import { DirectUpload } from "@rails/activestorage"

const input = document.querySelector('input[type=file]')

// Bind to file drop - use the ondrop on a parent element or use a
//  library like Dropzone
const onDrop = (event) => {
  event.preventDefault()
  const files = event.dataTransfer.files;
  Array.from(files).forEach(file => uploadFile(file))
}

// Bind to normal file selection
input.addEventListener('change', (event) => {
  Array.from(input.files).forEach(file => uploadFile(file))
  // you might clear the selected files from the input
  input.value = null
})

const uploadFile = (file) => {
  // your form needs the file_field direct_upload: true, which
  //  provides data-direct-upload-url
  const url = input.dataset.directUploadUrl
  const upload = new DirectUpload(file, url)

  upload.create((error, blob) => {
    if (error) {
      // Handle the error
    } else {
      // Add an appropriately-named hidden input to the form with a
      //  value of blob.signed_id so that the blob ids will be
      //  transmitted in the normal upload flow
      const hiddenField = document.createElement('input')
      hiddenField.setAttribute("type", "hidden");
      hiddenField.setAttribute("value", blob.signed_id);
      hiddenField.name = input.name
      document.querySelector('form').appendChild(hiddenField)
    }
  })
}
```

### Track the Progress of the File Upload

When using the `DirectUpload` constructor, it is possible to include a third
parameter. This will allow the `DirectUpload` object to invoke the
`directUploadWillStoreFileWithXHR` method during the upload process. You can
then attach your own progress handler to the XHR to suit your needs.

```js
import { DirectUpload } from "@rails/activestorage"

class Uploader {
  constructor(file, url) {
    this.upload = new DirectUpload(file, url, this)
  }

  uploadFile(file) {
    this.upload.create((error, blob) => {
      if (error) {
        // Handle the error
      } else {
        // Add an appropriately-named hidden input to the form
        // with a value of blob.signed_id
      }
    })
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress",
      event => this.directUploadDidProgress(event))
  }

  directUploadDidProgress(event) {
    // Use event.loaded and event.total to update the progress bar
  }
}
```

### Integrating with Libraries or Frameworks

Once you receive a file from the library you have selected, you need to create a
`DirectUpload` instance and use its `create` method to initiate the upload
process, adding any required additional headers as necessary. The "create"
method also requires a callback function to be provided that will be triggered
once the upload has finished.

```js
import { DirectUpload } from "@rails/activestorage"

class Uploader {
  constructor(file, url, token) {
    const headers = { 'Authentication': `Bearer ${token}` }
    // INFO: Sending headers is an optional parameter. If you choose not to send headers,
    //       authentication will be performed using cookies or session data.
    this.upload = new DirectUpload(file, url, this, headers)
  }

  uploadFile(file) {
    this.upload.create((error, blob) => {
      if (error) {
        // Handle the error
      } else {
        // Use the with blob.signed_id as a file reference in next request
      }
    })
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress",
      event => this.directUploadDidProgress(event))
  }

  directUploadDidProgress(event) {
    // Use event.loaded and event.total to update the progress bar
  }
}
```

To implement customized authentication, a new controller must be created on the
Rails application, similar to the following:

```ruby
class DirectUploadsController < ActiveStorage::DirectUploadsController
  skip_forgery_protection
  before_action :authenticate!

  def authenticate!
    @token = request.headers["Authorization"]&.split&.last

    head :unauthorized unless valid_token?(@token)
  end
end
```

NOTE: Using [Direct Uploads](#direct-uploads) can sometimes result in a file
that uploads, but never attaches to a record. Consider [purging unattached
uploads](#purging-unattached-uploads-and-detach).

Testing
-------

There is a
[`file_fixture_upload`](https://api.rubyonrails.org/classes/ActionDispatch/TestProcess/FixtureFile.html#method-i-file_fixture_upload)
helper method to test uploading a file in an integration or controller test.
Please see the [Testing guide](testing.html#testing-active-storage) for details.
