# Active Storage

Active Storage makes it simple to upload and reference files in cloud services, like Amazon S3 or Google Cloud Storage,
and attach those files to Active Records. It also provides a disk service for testing or local deployments, but the
focus is on cloud storage.

Files can uploaded from the server to the cloud or directly from the client to the cloud.

Image files can further more be transformed using on-demand variants for quality, aspect ratio, size, or any other
MiniMagick supported transformation.

## Compared to other storage solutions

A key difference to how Active Storage works compared to other attachment solutions in Rails is through the use of built-in [Blob](https://github.com/rails/activestorage/blob/master/app/models/active_storage/blob.rb) and [Attachment](https://github.com/rails/activestorage/blob/master/app/models/active_storage/attachment.rb) models (backed by Active Record). This means existing application models do not need to be modified with additional columns to associate with files. Active Storage uses polymorphic associations via the join model of `Attachment`, which then connects to the actual `Blob`.

These `Blob` models are intended to be immutable in spirit. One file, one blob. You can associate the same blob with multiple application models as well. And if you want to do transformations of a given `Blob`, the idea is that you'll simply create a new one, rather than attempt to mutate the existing (though of course you can delete that later if you don't need it).

## Examples

One attachment:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

user.avatar.attach io: File.open("~/face.jpg"), filename: "avatar.jpg", content_type: "image/jpg"
user.avatar.attached? # => true

user.avatar.purge
user.avatar.attached? # => false

url_for(user.avatar) # Generate a permanent URL for the blob, which upon access will redirect to a temporary service URL.

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
<%= form_with model: @message do |form| %>
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
<%= image_tag url_for(user.avatar.variant(resize: "100x100")) %>
```

## Installation

1. Add `gem "activestorage", git: "https://github.com/rails/activestorage.git"` to your Gemfile.
2. Add `require "active_storage"` to config/application.rb, after `require "rails/all"` line.
3. Run `rails activestorage:install` to create needed directories, migrations, and configuration.
4. Configure the storage service in `config/environments/*` with `config.active_storage.service = :local`
   that references the services configured in `config/storage_services.yml`.
5. Optional: Add `gem "aws-sdk", "~> 2"` to your Gemfile if you want to use AWS S3.
6. Optional: Add `gem "google-cloud-storage", "~> 1.3"` to your Gemfile if you want to use Google Cloud Storage.
7. Optional: Add `gem "mini_magick"` to your Gemfile if you want to use variants.

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
| `direct-uploads:start` | `<form>` | None | A form containing files for direct upload fields was submit. |
| `direct-upload:initialize` | `<input>` | `{id, file}` | Dispatched for every file after form submission. |
| `direct-upload:start` | `<input>` | `{id, file}` | A direct upload is starting. |
| `direct-upload:before-blob-request` | `<input>` | `{id, file, xhr}` | Before making a request to your application for direct upload metadata. |
| `direct-upload:before-storage-request` | `<input>` | `{id, file, xhr}` | Before making a request to store a file. |
| `direct-upload:progress` | `<input>` | `{id, file, progress}` | As requests to store files progress. |
| `direct-upload:error` | `<input>` | `{id, file, error}` | An error occurred. An `alert` will display unless this event is canceled. |
| `direct-upload:end` | `<input>` | `{id, file}` | A direct upload has ended. |
| `direct-uploads:end` | `<form>` | None | All direct uploads have ended. |

## Compatibility & Expectations

Active Storage only works with the development version of Rails 5.2+ (as of July 19, 2017). This separate repository is a staging ground for the upcoming inclusion in rails/rails prior to the Rails 5.2 release. It is not intended to be a long-term stand-alone repository.

Furthermore, this repository is likely to be in heavy flux prior to the merge to rails/rails. You're heartedly encouraged to follow along and even use Active Storage in this phase, but don't be surprised if the API suffers frequent breaking changes prior to the merge.

## Todos

- Convert MirrorService to use threading
- Read metadata via Marcel?
- Add Migrator to copy/move between services

## License

Active Storage is released under the [MIT License](https://opensource.org/licenses/MIT).
