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

*   Fix a bug where type casting of string to `Time` and `DateTime` doesn't
    calculate minus minute value in TZ offset correctly.

    *Akira Matsuda*

*   Port the `BeforeTypeCast` module to Active Model. Classes that include
    `ActiveModel::Attributes` will now automatically define methods such as
    `*_before_type_cast`, `*_for_database`, etc. These methods behave the same
    for Active Model as they do for Active Record.

    *Akira Matsuda*

*   Port the `type_for_attribute` method to Active Model. Classes that include
    `ActiveModel::Attributes` will now provide this method. This method behaves
    the same for Active Model as it does for Active Record.

      ```ruby
      class MyModel
        include ActiveModel::Attributes

        attribute :my_attribute, :integer
      end

      MyModel.type_for_attribute(:my_attribute) # => #<ActiveModel::Type::Integer ...>
      ```

    *Jonathan Hefner*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activemodel/CHANGELOG.md) for previous changes.
