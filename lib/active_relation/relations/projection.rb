module ActiveRelation
  module Relations
    class Projection < Compound
      attr_reader :relation, :attributes
  
      def initialize(relation, *attributes)
        @relation, @attributes = relation, attributes
      end
  
      def ==(other)
        relation == other.relation and attributes == other.attributes
      end
  
      def qualify
        Projection.new(relation.qualify, *attributes.collect(&:qualify))
      end
    end
  end
end