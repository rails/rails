module ActiveRelation
  module Predicates
    class Base
      def ==(other)
        self.class == other.class
      end
    end
  
    class Binary < Base
      attr_reader :attribute1, :attribute2

      def initialize(attribute1, attribute2)
        @attribute1, @attribute2 = attribute1, attribute2
      end

      def ==(other)
        super and @attribute1 == other.attribute1 and @attribute2 == other.attribute2
      end

      def qualify
        self.class.new(attribute1.qualify, attribute2.qualify)
      end

      def to_sql(options = {})
        "#{attribute1.to_sql} #{predicate_sql} #{attribute2.to_sql}"
      end
    end
  
    class Equality < Binary
      def ==(other)
        self.class == other.class and
          ((attribute1 == other.attribute1 and attribute2 == other.attribute2) or
           (attribute1 == other.attribute2 and attribute2 == other.attribute1))
      end

      protected
      def predicate_sql
        '='
      end
    end
  
    class GreaterThanOrEqualTo < Binary
      protected
      def predicate_sql
        '>='
      end
    end
  
    class GreaterThan < Binary
      protected
      def predicate_sql
        '>'
      end
    end
  
    class LessThanOrEqualTo < Binary
      protected
      def predicate_sql
        '<='
      end
    end
  
    class LessThan < Binary
      protected
      def predicate_sql
        '<'
      end
    end
  
    class Match < Base
      attr_reader :attribute, :regexp

      def initialize(attribute, regexp)
        @attribute, @regexp = attribute, regexp
      end
    end
  
    class RelationInclusion < Base
      attr_reader :attribute, :relation

      def initialize(attribute, relation)
        @attribute, @relation = attribute, relation
      end

      def ==(other)
        super and attribute == other.attribute and relation == other.relation
      end
      
      def to_sql(options = {})
        "#{attribute.to_sql} IN (#{relation.to_sql})"
      end
    end
  end
end