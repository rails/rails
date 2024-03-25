*   Introduce `ActiveModel::Type::Model` for model attributes

    ```ruby
    class Article
      include ActiveModel::Attributes

      attribute :author, class_name: "Person"
      attribute :comments, class_name: "Comment", array: true
    end

    class Person
      include ActiveModel::API
      include ActiveModel::Attributes

      attribute :name, :string
    end

    class Comment
      include ActiveModel::API
      include ActiveModel::Attributes

      attribute :body, :string
    end

    article = Article.new

    article.author = { name: "Arthur" }
    article.author.name # => "Arthur"

    article.comments = [{ body: "Hello" }, { body: "Goodbye" }]
    article.comments.map(&:body) # => ["Hello", "Goodbye"]
    ```

    *Sean Doyle*

*   Fix a bug where type casting of string to `Time` and `DateTime` doesn't
    calculate minus minute value in TZ offset correctly.

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
