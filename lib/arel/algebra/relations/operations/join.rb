module Arel
  class Join
    include Relation

    attributes :relation1, :relation2, :predicates
    deriving :==
    delegate :name, :to => :relation1

    def initialize(relation1, relation2 = Nil.instance, *predicates)
      @relation1, @relation2, @predicates = relation1, relation2, predicates
    end

    def hash
      @hash ||= :relation1.hash
    end

    def eql?(other)
      self == other
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

  module Relation
    def join?
      false
    end
  end
end
