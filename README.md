# Active Storage

Active Storage makes it simple to upload and reference files in cloud services, like Amazon S3 or Google Cloud Storage,
and attach those files to Active Records. It also provides a disk service for testing or local deployments, but the
focus is on cloud storage.

## Example

One attachment:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

user.avatar.attach io: File.open("~/face.jpg"), filename: "avatar.jpg", content_type: "image/jpg"
user.avatar.exist? # => true

user.avatar.purge
user.avatar.exist? # => false

user.avatar.url(expires_in: 5.minutes) # => /rails/blobs/<encoded-key>

class AvatarsController < ApplicationController
  def update
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

<%= form_with model: @message do |form| %>
  <%= form.text_field :title, placeholder: "Title" %><br>
  <%= form.text_area :content %><br><br>
  
  <%= form.file_field :images, multiple: true %><br>
  <%= form.submit %>
<% end %>

class MessagesController < ApplicationController
  def create
    message = Message.create! params.require(:message).permit(:title, :content)
    message.images.attach(params[:message][:images])
    redirect_to message
  end
end
```

## Installation

1. Add `require "active_storage"` to config/application.rb.
2. Run rails activestorage:install to create needed directories, migrations, and configuration.
3. Configure the storage service in config/environments/* with `config.active_storage.service = :local`
   that references the services configured in config/storage_services.yml.

## Todos

- Strip Download of its resposibilities and delete class
- Proper logging
- Convert MirrorService to use threading
- Read metadata via Marcel?
- Add Migrator to copy/move between services
- Explore direct uploads to cloud
- Extract VerifiedKeyWithExpiration into Rails as a feature of MessageVerifier

## License

Active Storage is released under the [MIT License](https://opensource.org/licenses/MIT).
