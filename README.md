# Active Vault

...

## Example

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

user.avatar.attach io: File.open("~/face.jpg"), filename: "avatar.jpg", content_type: "image/jpg"
user.avatar.exist? # => true

user.avatar.purge
user.avatar.exist? # => false

user.image.url(expires_in: 5.minutes) # => /rails/blobs/<encoded-key>

class AvatarsController < ApplicationController
  def update
    Current.user.avatar.attach(params.require(:avatar))
    redirect_to Current.user
  end
end
```

## License

Active Vault is released under the [MIT License](https://opensource.org/licenses/MIT).
