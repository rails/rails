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
