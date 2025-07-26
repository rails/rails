*   Introduce `ActiveModel::NestedAttributes`

    Handle assignment of `_attributes`-suffixed values in an ActionView- and
    ActionPack-compliant way:

    ```ruby
    class Article
      include ActiveModel::Model
      include ActiveModel::NestedAttributes

      attr_accessor :author
      attr_accessor :tags

      accepts_nested_attributes_for :author, class_name: Author
      accepts_nested_attributes_for :tags, class_name: Tag
    end


    article = Article.new(
      author_attributes: { name: "Pseudo Nym" },
      tags_attributes: {
         0 => { name: "actionview" },
         1 => { name: "actionpack" },
      }
    )

    article.author.name # => "Pseudo Nym"
    article.tags.pluck(:name) # => ["actionview", "actionpack"]
    ```

    *Sean Doyle*

*   Add `except_on:` option for validation callbacks.

    *Ben Sheldon*

*   Backport `ActiveRecord::Normalization` to `ActiveModel::Attributes::Normalization`

    ```ruby
    class User
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      attribute :email, :string

      normalizes :email, with: -> email { email.strip.downcase }
    end

    user = User.new
    user.email =    " CRUISE-CONTROL@EXAMPLE.COM\n"
    user.email # => "cruise-control@example.com"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
