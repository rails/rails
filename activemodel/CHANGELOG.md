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
