module ActiveRecord
  module AttributeDecorators # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :attribute_type_decorations, instance_accessor: false # :internal:
      self.attribute_type_decorations = Hash.new({})
    end

    module ClassMethods
      def decorate_attribute_type(column_name, decorator_name, &block)
        clear_caches_calculated_from_columns
        column_name = column_name.to_s

        # Create new hashes so we don't modify parent classes
        decorations_for_column = attribute_type_decorations[column_name]
        new_decorations = decorations_for_column.merge(decorator_name.to_s => block)
        self.attribute_type_decorations = attribute_type_decorations.merge(column_name => new_decorations)
      end

      private

      def add_user_provided_columns(*)
        super.map do |column|
          decorations = attribute_type_decorations[column.name].values
          decorated_type = decorations.inject(column.cast_type) do |type, block|
            block.call(type)
          end
          column.with_type(decorated_type)
        end
      end
    end
  end
end
