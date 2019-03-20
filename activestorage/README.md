# Active Storage

Active Storage makes it simple to upload and reference files in cloud services like [Amazon S3](https://aws.amazon.com/s3/), [Google Cloud Storage](https://cloud.google.com/storage/docs/), or [Microsoft Azure Storage](https://azure.microsoft.com/en-us/services/storage/), and attach those files to Active Records. Supports having one main service and mirrors in other services for redundancy. It also provides a disk service for testing or local deployments, but the focus is on cloud storage.

Files can be uploaded from the server to the cloud or directly from the client to the cloud.

Image files can furthermore be transformed using on-demand variants for quality, aspect ratio, size, or any other [MiniMagick](https://github.com/minimagick/minimagick) or [Vips](https://www.rubydoc.info/gems/ruby-vips/Vips/Image) supported transformation.

You can read more about Active Storage in the [Active Storage Overview](https://edgeguides.rubyonrails.org/active_storage_overview.html) guide.

## Compared to other storage solutions

A key difference to how Active Storage works compared to other attachment solutions in Rails is through the use of built-in [Blob](https://github.com/rails/rails/blob/master/activestorage/app/models/active_storage/blob.rb) and [Attachment](https://github.com/rails/rails/blob/master/activestorage/app/models/active_storage/attachment.rb) models (backed by Active Record). This means existing application models do not need to be modified with additional columns to associate with files. Active Storage uses polymorphic associations via the `Attachment` join model, which then connects to the actual `Blob`.

`Blob` models store attachment metadata (filename, content-type, etc.), and their identifier key in the storage service. Blob models do not store the actual binary data. They are intended to be immutable in spirit. One file, one blob. You can associate the same blob with multiple application models as well. And if you want to do transformations of a given `Blob`, the idea is that you'll simply create a new one, rather than attempt to mutate the existing one (though of course you can delete the previous version later if you don't need it).

## Installation

Run `rails active_storage:install` to copy over active_storage migrations.

NOTE: If the task cannot be found, verify that `require "active_storage/engine"` is present in `config/application.rb`.

## Examples

One attachment:

```ruby
class User < ApplicationRecord
  # Associates an attachment and a blob. When the user is destroyed they are
  # purged by default (models destroyed, and resource files deleted).
  has_one_attached :avatar
end

# Attach an avatar to the user.
user.avatar.attach(io: File.open("/path/to/face.jpg"), filename: "face.jpg", content_type: "image/jpg")

# Does the user have an avatar?
user.avatar.attached? # => true

# Synchronously destroy the avatar and actual resource files.
user.avatar.purge

# Destroy the associated models and actual resource files async, via Active Job.
user.avatar.purge_later

# Does the user have an avatar?
user.avatar.attached? # => false

# Generate a permanent URL for the blob that points to the application.
# Upon access, a redirect to the actual service endpoint is returned.
# This indirection decouples the public URL from the actual one, and
# allows for example mirroring attachments in different services for
# high-availability. The redirection has an HTTP expiration of 5 min.
url_for(user.avatar)

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

Variation of image attachment:

```erb
<%# Hitting the variant URL will lazy transform the original blob and then redirect to its new service location %>
<%= image_tag user.avatar.variant(resize_to_limit: [100, 100]) %>
```

## Direct uploads

Active Storage, with its included JavaScript library, supports uploading directly from the client to the cloud.

### Direct upload installation

1. Include `activestorage.js` in your application's JavaScript bundle.

    Using the asset pipeline:
    ```js
    //= require activestorage
    ```
    Using the npm package:
    ```js
    require("@rails/activestorage").start()
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

## License

Active Storage is released under the [MIT License](https://opensource.org/licenses/MIT).

## Support

API documentation is at:

* https://api.rubyonrails.org

Bug reports for the Ruby on Rails project can be filed here:

* https://github.com/rails/rails/issues

Feature requests should be discussed on the rails-core mailing list here:

* https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-core
