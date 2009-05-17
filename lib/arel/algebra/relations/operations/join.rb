module Arel
  class Join < Relation
    attributes :join_sql, :relation1, :relation2, :predicates
    deriving :==
    delegate :engine, :name, :to => :relation1
    hash_on :relation1

    def initialize(join_sql, relation1, relation2 = Nil.instance, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end

    def attributes
      @attributes ||= (relation1.externalize.attributes +
        relation2.externalize.attributes).collect { |a| a.bind(self) }
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
  end

  class Relation
    def join?
      false
    end
  end
end
