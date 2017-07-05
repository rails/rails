# Active Vault

...

## Example

```ruby
class Person < ApplicationRecord
  has_file :avatar
end

avatar.image.url(expires_in: 5.minutes)

class AvatarsController < ApplicationController
  def create
    # @avatar = Avatar.create \
    #   image: ActiveVault::Blob.save!(file_name: params.require(:name), content_type: request.content_type, data: request.body)
    @avatar = Avatar.create! image: Avatar.image.extract_from(request)
  end
end


class ProfilesController < ApplicationController
  def update
    @person.update! avatar: @person.avatar.update!(image: )
  end
end
```

## License

Active Vault is released under the [MIT License](https://opensource.org/licenses/MIT).
