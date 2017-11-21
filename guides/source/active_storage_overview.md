**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Active Storage
==============

This guide covers how to attach files to your Active Record models.

After reading this guide, you will know:

* How to attach one or many files to a record.
* How to delete an attached file.
* How to link to an attached file.
* How to use variants to transform images.
* How to generate an image representation of a non-image file, such as a PDF or a video.
* How to send file uploads directly from browsers to a storage service,
  bypassing your application servers.
* How to implement support for additional storage services.
* How to clean up files stored during testing.

--------------------------------------------------------------------------------

What is Active Storage?
-----------------------

Active Storage facilitates uploading files to a cloud storage service like
Amazon S3, Google Cloud Storage, or Microsoft Azure Storage and attaching those
files to Active Record objects. It comes with a local disk-based service for
development and testing and supports mirroring files to subordinate services for
backups and migrations.

Using Active Storage, an application can transform image uploads with
[ImageMagick](https://www.imagemagick.org), generate image representations of
non-image uploads like PDFs and videos, and extract metadata from arbitrary
files.

## Setup

To setup an existing application after upgrading to Rails 5.2, run `rails
active_storage:install`. If you're creating a new project with Rails 5.2,
ActiveStorage will be installed by default. Installation generates a migration
to add the tables needed to store attachments.

If you wish to transform your images, add `mini_magick` to your Gemfile:

``` ruby
gem 'mini_magick'
```

Inside a Rails application, you can set up your services through the generated
`config/storage.yml` file and reference one of the supported service types under
the `service` key.

### Disk Service
To use the Disk service:

``` yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

### Amazon S3 Service

To use Amazon S3:
``` yaml
local:
  service: S3
  access_key_id: ""
  secret_access_key: ""
  region: ""
  bucket: ""
```
Also, add the S3 client gem to your Gemfile:

``` ruby
gem "aws-sdk-s3", require: false
```
### Microsoft Azure Storage Service

To use Microsoft Azure Storage:

``` yaml
local:
  service: AzureStorage
  path: ""
  storage_account_name: ""
  storage_access_key: ""
  container: ""
```

Also, add the Microsoft Azure Storage client gem to your Gemfile:

``` ruby
gem "azure-storage", require: false
```

### Google Cloud Storage Service

To use Google Cloud Storage:

``` yaml
local:
  service: GCS
  keyfile: {
    type: "service_account",
    project_id: "",
    private_key_id: "",
    private_key: "",
    client_email: "",
    client_id: "",
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://accounts.google.com/o/oauth2/token",
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    client_x509_cert_url: ""
  }
  project: ""
  bucket: ""
```

Also, add the Google Cloud Storage client gem to your Gemfile:

``` ruby
gem "google-cloud-storage", "~> 1.3", require: false
```

### Mirror Service

You can keep multiple services in sync by defining a mirror service. When
a file is uploaded or deleted, it's done across all the mirrored services.
Define each of the services you'd like to use as described above and then define
a mirrored service which references them.

``` yaml
s3_west_coast:
  service: S3
  access_key_id: ""
  secret_access_key: ""
  region: ""
  bucket: ""

s3_east_coast:
  service: S3
  access_key_id: ""
  secret_access_key: ""
  region: ""
  bucket: ""

production:
  service: Mirror
  primary: s3_east_coast
  mirrors:
    - s3_west_coast
```

In your application's configuration, specify the service to use like this:

``` ruby
config.active_storage.service = :local
```

Like other configuration options, you can set the service application wide in
`application.rb`, or per environment in `config/environments/{environment}.rb`.
For example, you might want development and test to use the Disk service instead
of a cloud service.

Attach Files to a Model
--------------------------
One or more files can be attached to a model.

One attachment:

```ruby
class User < ApplicationRecord
  # Associates an attachment and a blob. When the user is destroyed they are
  # purged by default (models destroyed, and resource files deleted).
  has_one_attached :avatar
end

# Attach an avatar to the user.
user.avatar.attach(io: File.open("/path/to/face.jpg"), filename: "face.jpg", content_type: "image/jpg")

class AvatarsController < ApplicationController
  def update
    # params[:avatar] contains a ActionDispatch::Http::UploadedFile object
    Current.user.avatar.attach(params.require(:avatar))
    redirect_to Current.user
  end
end
```

Many attachments:

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

```erb
<%= form_with model: @message, local: true do |form| %>
  <%= form.text_field :title, placeholder: "Title" %><br>
  <%= form.text_area :content %><br><br>

  <%= form.file_field :images, multiple: true %><br>
  <%= form.submit %>
<% end %>
```

```ruby
class MessagesController < ApplicationController
  def index
    # Use the built-in with_attached_images scope to avoid N+1
    @messages = Message.all.with_attached_images
  end

  def create
    message = Message.create! params.require(:message).permit(:title, :content)
    message.images.attach(params[:message][:images])
    redirect_to message
  end

  def show
    @message = Message.find(params[:id])
  end
end
```

Remove File Attached to Model
-------------------------------

To remove an attachment from a model, call `purge` on the attachment. Removal
can be done in the background if your application is setup to use ActiveJob.
Purging deletes the blob and the file from the storage service.

```ruby
# Synchronously destroy the avatar and actual resource files.
user.avatar.purge

# Destroy the associated models and actual resource files async, via Active Job.
user.avatar.purge_later
```

Link to Attachments
----------------------

Generate a permanent URL for the blob that points to the application. Upon
access, a redirect to the actual service endpoint is returned. This indirection
decouples the public URL from the actual one, and allows, for example, mirroring
attachments in different services for high-availability. The redirection has an
HTTP expiration of 5 min.

```ruby
url_for(user.avatar)
```

To create a download link, use the `rails_blob_{path|url}` helper. Using this
helper will allow you to set disposition.

```ruby
rails_blob_path(user.avatar, disposition: "attachment")
```

Create Variations of Attached Image
-----------------------------------

Sometimes your application will require images in a different format than
what was uploaded. To create variation of the image, call `variant` on the Blob.
You can pass any [MiniMagick](https://github.com/minimagick/minimagick)
supported transformation.

When the browser hits the variant URL, ActiveStorage will lazy transform the
original blob into the format you specified and redirect to its new service
location.

```erb
<%= image_tag user.avatar.variant(resize: "100x100") %>
```

Create Image Previews of Attachments
------------------------------------
Previews can be generated from some non-image formats. ActiveStorage supports
Previewers for videos and PDFs.

```erb
<ul>
  <% @message.files.each do |file| %>
    <li>
      <%= image_tag file.preview(resize: "100x100>") %>
    </li>
  <% end %>
</ul>
```

Upload Directly to Service
--------------------------

Active Storage, with its included JavaScript library, supports uploading
directly from the client to the cloud.

### Direct upload installation

1. Include `activestorage.js` in your application's JavaScript bundle.

    Using the asset pipeline:
    ```js
    //= require activestorage
    ```
    Using the npm package:
    ```js
    import * as ActiveStorage from "activestorage"
    ActiveStorage.start()
    ```
2. Annotate file inputs with the direct upload URL.

    ```ruby
    <%= form.file_field :attachments, multiple: true, direct_upload: true %>
    ```
3. That's it! Uploads begin upon form submission.

### Direct upload JavaScript events

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

NOTE: Is there more to using the direct upload than this? How does one associate
the result with the form submission, or does that happen automatically?

Clean up Stored Files Store During System Tests
-----------------------------------------------

System tests clean up test data by rolling back a transaction. Because destroy
is never called on an object, the attached files are never cleaned up. If you
want to clear the files, you can do it in an `after_teardown` callback. Doing it
here ensures that all connections created during the test are complete and
you won't receive an error from ActiveStorage saying it can't find a file.

``` ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  def remove_uploaded_files
    FileUtils.rm_rf("#{Rails.root}/storage_test")
  end

  def after_teardown
    super
    remove_uploaded_files
  end
end
```

If your system tests verify the deletion of a model with attachments and your
using ActiveJob, set your test environment to use the inline queue adapter so
the purge job is executed immediately rather at an unknown time in the future.

You may also want to use a separate service definition for the test environment
so your tests don't delete the files you create during development.

``` ruby
# Use inline job processing to make things happen immediately
config.active_job.queue_adapter = :inline

# Separate file storage in the test environment
config.active_storage.service = :local_test
```

Add Support Additional Cloud Service
------------------------------------

ActiveStorage ships with support for Amazon S3, Google Cloud Storage, and Azure.
If you need to support a cloud service other these, you will need to implement
the Service. Each service extends
[`ActiveStorage::Service`](https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/service.rb)
by implementing the methods necessary to upload and download files to the cloud.

The easiest way to understand what's necessary is to examine the existing
implementations.

Some services are supported by community maintained gems:

* [OpenStack](https://github.com/jeffreyguenther/activestorage-openstack)
