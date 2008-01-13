module ActiveRelation
  module Relations
    class Alias < Compound
      attr_reader :alias
  
      def initialize(relation, aliaz)
        @relation, @alias = relation, aliaz
      end
  
      def ==(other)
        relation == other.relation and self.alias == other.alias
      end
      
      def to_sql(options = {})
        super + " AS #{@alias}"
      end
    end
  end
end