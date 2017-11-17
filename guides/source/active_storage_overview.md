**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Active Storage
==============

This guide covers how to attach files to your ActiveRecord models.

After reading this guide, you will know:

* How to attach a file(s) to a model.
* How to remove the attached file.
* How to link to the attached file.
* How to create variations of an image.
* How to generate a preview for files other than images.
* How to upload files directly to a service.
* How to implement a download link.
* How to add support for additional cloud services.
* How to clean up files stored during testing.

--------------------------------------------------------------------------------

Active Storage makes it simple to upload and reference files in cloud services
like Amazon S3, Google Cloud Storage, or Microsoft Azure Storage, and attach
those files to Active Records. Supports having one main service and mirrors in
other services for redundancy. It also provides a disk service for testing or
local deployments, but the focus is on cloud storage.

Files can be uploaded from the server to the cloud or directly from the client
to the cloud.

Image files can furthermore be transformed using on-demand variants for quality,
aspect ratio, size, or any other
[MiniMagick](https://github.com/minimagick/minimagick) supported transformation.

## Compared to other storage solutions

A key difference to how Active Storage works compared to other attachment
solutions in Rails is through the use of built-in
[Blob](https://github.com/rails/rails/blob/master/activestorage/app/models/active_storage/blob.rb)
and
[Attachment](https://github.com/rails/rails/blob/master/activestorage/app/models/active_storage/attachment.rb)
models (backed by Active Record). This means existing application models do not
need to be modified with additional columns to associate with files. Active
Storage uses polymorphic associations via the `Attachment` join model, which
then connects to the actual `Blob`.

`Blob` models store attachment metadata (filename, content-type, etc.), and
their identifier key in the storage service. Blob models do not store the actual
binary data. They are intended to be immutable in spirit. One file, one blob.
You can associate the same blob with multiple application models as well. And if
you want to do transformations of a given `Blob`, the idea is that you'll simply
create a new one, rather than attempt to mutate the existing one (though of
course you can delete the previous version later if you don't need it).


## Setup

To setup an existing application after upgrading to Rails 5.2, run `rails active_storage:install`. If you're creating a new project with Rails 5.2, ActiveStorage will be installed by default. This generates the tables for the
`Attachment` and `Blob` models.

Inside a Rails application, you can set-up your services through the
generated `config/storage.yml` file and reference one
of the aforementioned constant under the +service+ key. For example:

``` yaml
  local:
    service: Disk
    root: <%= Rails.root.join("storage") %>
```
NOTE: Should we include the required keys for all the supported services?
NOTE: Should we mention the mirror service and how to set it up?

In your application's configuration, specify the service to
use like this:

``` ruby
config.active_storage.service = :local
```

Like other configuration options, you can set the service application wide, or per
environment. For example, you might want development and test to use the Disk
service instead of a cloud service.

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
decouples the public URL from the actual one, and allows for example mirroring
attachments in different services for high-availability. The redirection has an
HTTP expiration of 5 min.

```ruby
url_for(user.avatar)
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

Implement Direct Download Link
------------------------------

TODO

Clean up Stored Files Store During System Tests
-----------------------------------------------

System tests clean up test data by rolling back a transaction. Because destroy
is never called on an object, the attached files are never cleaned up. If you
want to clear the files, you can do it in an `after_teardown` callback. Doing it
here ensures that all connections to created during the test are complete and
you won't get an error from ActiveStorage saying it can't find a file.

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
