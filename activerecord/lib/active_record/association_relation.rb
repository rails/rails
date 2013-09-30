module ActiveRecord
  class AssociationRelation < Relation
    delegate :owner, :reflection, to: :proxy_association
    delegate :scope, :scope?, to: :reflection, prefix: true

    def initialize(klass, table, association)
      super(klass, table)
      @association = association
    end

    def proxy_association
      @association
    end

    def apply_reflection_scope
      reflection_scope? ? instance_exec(owner, &reflection_scope) : self
    end

    private

    def exec_queries
      super.each { |r| @association.set_inverse_instance r }
    end
  end
end
