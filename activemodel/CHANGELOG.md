*   Add `ActiveModel::Validations::ModelValidator`

    This validator is similar to `ActiveRecord::Validations::AssociatedValidator`
    but doesn't require the associated object to be an `ActiveRecord` object.

    It is useful when building form objects that aren't backed by a database or
    to save multiple objects at once.

    Ex:

        class Author
          include ActiveModel::Model

          validates_presence_of :name
        end

        class Book
          include ActiveModel::Model

          attr_accessor :author, :title

          validates_model :author
        end

        author = Author.new
        book = Book.new(title: "A book", author: author)
        book.valid? # => false

        book.errors[:author] # => ["is invalid"]
        author.errors[:name] # => ["can't be blank"]

    *Matheus Richard*

*   Add a load hook `active_model_translation` for `ActiveModel::Translation`.

    *Shouichi Kamiya*

*   Add `raise_on_missing_translations` option to `ActiveModel::Translation`.
    When the option is set, `human_attribute_name` raises an error if a translation of the given attribute is missing.

    ```ruby
    # ActiveModel::Translation.raise_on_missing_translations = false
    Post.human_attribute_name("title")
    => "Title"

    # ActiveModel::Translation.raise_on_missing_translations = true
    Post.human_attribute_name("title")
    => Translation missing. Options considered were: (I18n::MissingTranslationData)
        - en.activerecord.attributes.post.title
        - en.attributes.title

                raise exception.respond_to?(:to_exception) ? exception.to_exception : exception
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ```

    *Shouichi Kamiya*

*   Introduce `ActiveModel::AttributeAssignment#attribute_writer_missing`

    Provide instances with an opportunity to gracefully handle assigning to an
    unknown attribute:

    ```ruby
    class Rectangle
      include ActiveModel::AttributeAssignment

      attr_accessor :length, :width

      def attribute_writer_missing(name, value)
        Rails.logger.warn "Tried to assign to unknown attribute #{name}"
      end
    end

    rectangle = Rectangle.new
    rectangle.assign_attributes(height: 10) # => Logs "Tried to assign to unknown attribute 'height'"
    ```

    *Sean Doyle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activemodel/CHANGELOG.md) for previous changes.
