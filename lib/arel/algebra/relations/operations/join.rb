module Arel
  class Join
    include Relation

    attr_reader :relation1, :relation2, :predicates

    def initialize(relation1, relation2 = Nil.instance, *predicates)
      @relation1  = relation1
      @relation2  = relation2
      @predicates = predicates
    end

    def name
      relation1.name
    end

    def hash
      @hash ||= :relation1.hash
    end

    def attributes
      @attributes ||= (relation1.externalize.attributes | relation2.externalize.attributes).bind(self)
    end

    def wheres
      # TESTME bind to self?
      relation1.externalize.wheres
    end

    def ons
      @ons ||= @predicates.collect { |p| p.bind(self) }
    end

    # TESTME
    def externalizable?
      relation1.externalizable? or relation2.externalizable?
    end

    def join?
      true
    end

    def engine
      relation1.engine != relation2.engine ? Memory::Engine.new : relation1.engine
    end

    def == other
      super || Join === other &&
        relation1  == other.relation1 &&
        relation2  == other.relation2 &&
        predicates == other.predicates
    end

    # FIXME remove this.  :'(
    alias :eql? :==

    def eval
      result = []
      relation1.call.each do |row1|
        relation2.call.each do |row2|
          combined_row = row1.combine(row2, self)
          if predicates.all? { |p| p.eval(combined_row) }
            result << combined_row
          end
        end
      end
      result
    end
  end

  class InnerJoin  < Join; end
  class OuterJoin  < Join; end
  class StringJoin < Join
    def externalizable?
      relation1.externalizable?
    end

    def attributes
      relation1.externalize.attributes
    end

    def engine
      relation1.engine
    end
  end
end
