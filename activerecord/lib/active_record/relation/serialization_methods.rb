module ActiveRecord
  class Relation
    module SerializationMethods
      # Serializes the relation objects Array.
      def encode_with(coder)
        coder.represent_seq(nil, to_a)
      end

      def as_json(options = nil) #:nodoc:
        to_a.as_json(options)
      end

      # Returns sql statement for the relation.
      #
      #   User.where(name: 'Oscar').to_sql
      #   # => SELECT "users".* FROM "users"  WHERE "users"."name" = 'Oscar'
      def to_sql
        @to_sql ||= begin
          relation   = self
          connection = klass.connection
          visitor    = connection.visitor

          if eager_loading?
            find_with_associations { |rel| relation = rel }
          end

          binds = relation.bound_attributes
          binds = connection.prepare_binds_for_database(binds)
          binds.map! { |value| connection.quote(value) }
          collect = visitor.accept(relation.arel.ast, Arel::Collectors::Bind.new)
          collect.substitute_binds(binds).join
        end
      end
    end
  end
end
