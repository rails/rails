module ActiveRecord
  module Types
    extend ActiveSupport::Concern

    module ClassMethods

      def attribute_types
        attribute_types = {}
        columns.each do |column|
          options = {}
          options[:time_zone_aware] = time_zone_aware?(column.name)
          options[:serialize]       = serialized_attributes[column.name]

          attribute_types[column.name] = to_type(column, options)
        end
        attribute_types
      end

      private

      def to_type(column, options = {})
        type_class = if options[:time_zone_aware]
          Type::TimeWithZone
        elsif options[:serialize]
          Type::Serialize
        elsif [ :integer, :float, :decimal ].include?(column.type)
          Type::Number
        else
          Type::Object
        end

        type_class.new(column, options)
      end

    end

  end
end
