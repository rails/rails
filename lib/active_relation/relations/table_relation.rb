module ActiveRelation
  module Relations
    class Table < Base
      attr_reader :table
  
      def initialize(table)
        @table = table
      end
  
      def attributes
        attributes_by_name.values
      end
  
      def qualify
        Rename.new self, qualifications
      end
    
      protected
      def attribute(name)
        attributes_by_name[name.to_s]
      end
  
      private
      def attributes_by_name
        @attributes_by_name ||= connection.columns(table, "#{table} Columns").inject({}) do |attributes_by_name, column|
          attributes_by_name.merge(column.name => ActiveRelation::Primitives::Attribute.new(self, column.name.to_sym))
        end
      end
  
      def qualifications
        attributes.zip(attributes.collect(&:qualified_name)).to_hash
      end
    end
  end
end