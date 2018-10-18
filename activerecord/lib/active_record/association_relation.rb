# frozen_string_literal: true

module ActiveRecord
  class AssociationRelation < Relation
    def initialize(klass, association)
      super(klass)
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
        super do |record|
          @association.set_inverse_instance_from_queries(record)
          yield record if block_given?
        end
      end
  end
end
