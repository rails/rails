module ActiveRecord
  module AttributeDecorators # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :attribute_type_decorations, instance_accessor: false # :internal:
      self.attribute_type_decorations = TypeDecorator.new
    end

    module ClassMethods
      def decorate_attribute_type(column_name, decorator_name, &block)
        clear_caches_calculated_from_columns
        column_name = column_name.to_s

        # Create new hashes so we don't modify parent classes
        self.attribute_type_decorations = attribute_type_decorations.merge(column_name, decorator_name, block)
      end

      private

      def add_user_provided_columns(*)
        super.map do |column|
          decorated_type = attribute_type_decorations.apply(column.name, column.cast_type)
          column.with_type(decorated_type)
        end
      end
    end

    class TypeDecorator
      delegate :clear, to: :@decorations

      def initialize(decorations = Hash.new({}))
        @decorations = decorations
      end

      def merge(attribute_name, decorator_name, block)
        decorations_for_attribute = @decorations[attribute_name]
        new_decorations = decorations_for_attribute.merge(decorator_name.to_s => block)
        TypeDecorator.new(@decorations.merge(attribute_name => new_decorations))
      end

      def apply(attribute_name, type)
        decorations = @decorations[attribute_name].values
        decorations.inject(type) do |new_type, block|
          block.call(new_type)
        end
      end
    end
  end
end
