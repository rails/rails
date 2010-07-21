module Arel
  class Expression < Attribute
    attr_reader :attribute
    alias :name :alias

    def initialize(attribute, aliaz = nil, ancestor = nil)
      super(attribute.relation, aliaz, :alias => aliaz, :ancestor => ancestor)
      @attribute = attribute
    end

    def == other
      super && Expression === other && attribute == other.attribute
    end

    def aggregation?
      true
    end

    module Transformations
      def as(aliaz)
        self.class.new(attribute, aliaz, self)
      end

      def bind(new_relation)
        new_relation == relation ? self : self.class.new(attribute.bind(new_relation), @alias, self)
      end

      def to_attribute(relation)
        Attribute.new(relation, @alias, :ancestor => self)
      end
    end
    include Transformations
  end

  class Count    < Expression; end
  class Distinct < Expression; end
  class Sum      < Expression; end
  class Maximum  < Expression; end
  class Minimum  < Expression; end
  class Average  < Expression; end
end

