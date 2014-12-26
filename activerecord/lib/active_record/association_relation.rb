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
      other == to_a
    end

    private

    def exec_queries
      super.each { |r| @association.set_inverse_instance r }
    end
  end
end
