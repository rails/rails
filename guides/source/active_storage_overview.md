**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Active Storage Overview
=======================

This guide covers how to attach files to your Active Record models.

After reading this guide, you will know:

* How to attach one or many files to a record.
* How to delete an attached file.
* How to link to an attached file.
* How to use variants to transform images.
* How to generate an image representation of a non-image file, such as a PDF or a video.
* How to send file uploads directly from browsers to a storage service,
  bypassing your application servers.
* How to clean up files stored during testing.
* How to implement support for additional storage services.

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

Active Storage uses two tables in your application’s database named
`active_storage_blobs` and `active_storage_attachments`. After upgrading your
application to Rails 5.2, run `rails active_storage:install` to generate a
migration that creates these tables. Use `rails db:migrate` to run the
migration.

Declare Active Storage services in `config/storage.yml`. For each service your
application uses, provide a name and the requisite configuration. The example
below declares three services named `local`, `test`, and `amazon`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

amazon:
  service: S3
  access_key_id: ""
  secret_access_key: ""
```

Tell Active Storage which service to use by setting
`Rails.application.config.active_storage.service`. Because each environment will
likely use a different service, it is recommended to do this on a
per-environment basis. To use the disk service from the previous example in the
development environment, you would add the following to
`config/environments/development.rb`:

```ruby
# Store files locally.
config.active_storage.service = :local
```

To use the Amazon S3 service in production, you add the following to
`config/environments/production.rb`:

```ruby
# Store files on Amazon S3.
config.active_storage.service = :amazon
```

Continue reading for more information on the built-in service adapters (e.g.
`Disk` and `S3`) and the configuration they require.

### Disk Service

Declare a Disk service in `config/storage.yml`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

### Amazon S3 Service

Declare an S3 service in `config/storage.yml`:

```yaml
amazon:
  service: S3
  access_key_id: ""
  secret_access_key: ""
  region: ""
  bucket: ""
```

Add the [`aws-sdk-s3`](https://github.com/aws/aws-sdk-ruby) gem to your `Gemfile`:

```ruby
gem "aws-sdk-s3", require: false
```

NOTE: The core features of Active Storage require the following permissions: `s3:ListBucket`, `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject`. If you have additional upload options configured such as setting ACLs then additional permissions may be required.

### Microsoft Azure Storage Service

Declare an Azure Storage service in `config/storage.yml`:

```yaml
azure:
  service: AzureStorage
  path: ""
  storage_account_name: ""
  storage_access_key: ""
  container: ""
```

Add the [`azure-storage`](https://github.com/Azure/azure-storage-ruby) gem to your `Gemfile`:

```ruby
gem "azure-storage", require: false
```

### Google Cloud Storage Service

Declare a Google Cloud Storage service in `config/storage.yml`:

```yaml
google:
  service: GCS
  credentials: <%= Rails.root.join("path/to/keyfile.json") %>
  project: ""
  bucket: ""
```

Optionally provide a Hash of credentials instead of a keyfile path:

```yaml
google:
  service: GCS
  credentials:
    type: "service_account"
    project_id: ""
    private_key_id: <%= Rails.application.credentials.dig(:gcs, :private_key_id) %>
    private_key: <%= Rails.application.credentials.dig(:gcs, :private_key) %>
    client_email: ""
    client_id: ""
    auth_uri: "https://accounts.google.com/o/oauth2/auth"
    token_uri: "https://accounts.google.com/o/oauth2/token"
    auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
    client_x509_cert_url: ""
  project: ""
  bucket: ""
```

Add the [`google-cloud-storage`](https://github.com/GoogleCloudPlatform/google-cloud-ruby/tree/master/google-cloud-storage) gem to your `Gemfile`:

```ruby
gem "google-cloud-storage", "~> 1.8", require: false
```

### Mirror Service

You can keep multiple services in sync by defining a mirror service. When a file
is uploaded or deleted, it's done across all the mirrored services. Mirrored
services can be used to facilitate a migration between services in production.
You can start mirroring to the new service, copy existing files from the old
service to the new, then go all-in on the new service. Define each of the
services you'd like to use as described above and reference them from a mirrored
service.

```yaml
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

NOTE: Files are served from the primary service.

Attaching Files to Records
--------------------------

### `has_one_attached`

The `has_one_attached` macro sets up a one-to-one mapping between records and
files. Each record can have one file attached to it.

For example, suppose your application has a `User` model. If you want each user to
have an avatar, define the `User` model like this:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

You can create a user with an avatar:

```ruby
class SignupController < ApplicationController
  def create
    user = User.create!(user_params)
    session[:user_id] = user.id
    redirect_to root_path
  end

  private
    def user_params
      params.require(:user).permit(:email_address, :password, :avatar)
    end
end
```

Call `avatar.attach` to attach an avatar to an existing user:

```ruby
Current.user.avatar.attach(params[:avatar])
```

Call `avatar.attached?` to determine whether a particular user has an avatar:

```ruby
Current.user.avatar.attached?
```

### `has_many_attached`

The `has_many_attached` macro sets up a one-to-many relationship between records
and files. Each record can have many files attached to it.

For example, suppose your application has a `Message` model. If you want each
message to have many images, define the `Message` model like this:

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

You can create a message with images:

```ruby
class MessagesController < ApplicationController
  def create
    message = Message.create!(message_params)
    redirect_to message
  end

  private
    def message_params
      params.require(:message).permit(:title, :content, images: [])
    end
end
```

Call `images.attach` to add new images to an existing message:

```ruby
@message.images.attach(params[:images])
```

Call `images.attached?` to determine whether a particular message has any images:

```ruby
@message.images.attached?
```

Removing Files
--------------

To remove an attachment from a model, call `purge` on the attachment. Removal
can be done in the background if your application is setup to use Active Job.
Purging deletes the blob and the file from the storage service.

```ruby
# Synchronously destroy the avatar and actual resource files.
user.avatar.purge

# Destroy the associated models and actual resource files async, via Active Job.
user.avatar.purge_later
```

Linking to Files
----------------

Generate a permanent URL for the blob that points to the application. Upon
access, a redirect to the actual service endpoint is returned. This indirection
decouples the public URL from the actual one, and allows, for example, mirroring
attachments in different services for high-availability. The redirection has an
HTTP expiration of 5 min.

```ruby
url_for(user.avatar)
```

To create a download link, use the `rails_blob_{path|url}` helper. Using this
helper allows you to set the disposition.

```ruby
rails_blob_path(user.avatar, disposition: "attachment")
```

Transforming Images
-------------------

To create variation of the image, call `variant` on the Blob.
You can pass any [MiniMagick](https://github.com/minimagick/minimagick)
supported transformation to the method.

To enable variants, add `mini_magick` to your `Gemfile`:

```ruby
gem 'mini_magick'
```

When the browser hits the variant URL, Active Storage will lazy transform the
original blob into the format you specified and redirect to its new service
location.

```erb
<%= image_tag user.avatar.variant(resize: "100x100") %>
```

Previewing Files
----------------

Some non-image files can be previewed: that is, they can be presented as images.
For example, a video file can be previewed by extracting its first frame. Out of
the box, Active Storage supports previewing videos and PDF documents.

```erb
<ul>
  <% @message.files.each do |file| %>
    <li>
      <%= image_tag file.preview(resize: "100x100>") %>
    </li>
  <% end %>
</ul>
```

WARNING: Extracting previews requires third-party applications, `ffmpeg` for
video and `mutool` for PDFs. These libraries are not provided by Rails. You must
install them yourself to use the built-in previewers. Before you install and use
third-party software, make sure you understand the licensing implications of
doing so.

Direct Uploads
--------------

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

### Example

You can use these events to show the progress of an upload.

![direct-uploads](https://user-images.githubusercontent.com/5355/28694528-16e69d0c-72f8-11e7-91a7-c0b8cfc90391.gif)

To show the uploaded files in a form:

```js
// direct_uploads.js

addEventListener("direct-upload:initialize", event => {
  const { target, detail } = event
  const { id, file } = detail
  target.insertAdjacentHTML("beforebegin", `
    <div id="direct-upload-${id}" class="direct-upload direct-upload--pending">
      <div id="direct-upload-progress-${id}" class="direct-upload__progress" style="width: 0%"></div>
      <span class="direct-upload__filename">${file.name}</span>
    </div>
  `)
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

Add styles:

```css
/* direct_uploads.css */

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

Discarding Files Stored During System Tests
-------------------------------------------

System tests clean up test data by rolling back a transaction. Because destroy
is never called on an object, the attached files are never cleaned up. If you
want to clear the files, you can do it in an `after_teardown` callback. Doing it
here ensures that all connections created during the test are complete and
you won't receive an error from Active Storage saying it can't find a file.

```ruby
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

If your system tests verify the deletion of a model with attachments and you're
using Active Job, set your test environment to use the inline queue adapter so
the purge job is executed immediately rather at an unknown time in the future.

You may also want to use a separate service definition for the test environment
so your tests don't delete the files you create during development.

```ruby
# Use inline job processing to make things happen immediately
config.active_job.queue_adapter = :inline

# Separate file storage in the test environment
config.active_storage.service = :local_test
```

Discarding Files Stored During Integration Tests
-------------------------------------------

Similarly to System Tests, files uploaded during Integration Tests will not be
automatically cleaned up. If you want to clear the files, you can do it in an
`after_teardown` callback. Doing it here ensures that all connections created
during the test are complete and you won't receive an error from Active Storage
saying it can't find a file.

```ruby
module ActionDispatch
  class IntegrationTest
    def remove_uploaded_files
      FileUtils.rm_rf(Rails.root.join('tmp', 'storage'))
    end

    def after_teardown
      super
      remove_uploaded_files
    end
  end
end
```

Implementing Support for Other Cloud Services
---------------------------------------------

If you need to support a cloud service other than these, you will need to
implement the Service. Each service extends
[`ActiveStorage::Service`](https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/service.rb)
by implementing the methods necessary to upload and download files to the cloud.
