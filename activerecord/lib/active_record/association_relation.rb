module ActiveRecord
  class AssociationRelation < Relation
    def initialize(klass, table, predicate_builder, association)
      super(klass, table, predicate_builder)
      @association = association
    end

    def proxy_association
      @association
    end

    def ==(other)
      other == records
    end

    def build(*args, &block)
      scoping { @association.build(*args, &block) }
    end
    alias new build

    def create(*args, &block)
      scoping { @association.create(*args, &block) }
    end

    def create!(*args, &block)
      scoping { @association.create!(*args, &block) }
    end

    private

    def exec_queries
      super.each { |r| @association.set_inverse_instance r }
    end
  end
end
