*   Add `ActiveRecord::Base.normalizes_each`, which behaves like
    `ActiveRecord::Base.normalizes`, but targets each attribute of the specified
    types. For example:

      ```ruby
      class Post < ActiveRecord::Base
        normalizes_each :string, :text, with: -> { _1.strip }
      end

      post = Post.new(title: "  Title", body: "Body.\n")
      post.title # => "Title"
      post.body  # => "Body."
      ```

    *Niklas Häusele* and *Jonathan Hefner*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
