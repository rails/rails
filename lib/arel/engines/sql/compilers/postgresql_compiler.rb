module Arel
  module SqlCompiler
    class PostgreSQLCompiler < GenericCompiler

      def select_sql
        if !orders.blank? && using_distinct_on?
          subquery = build_query \
            "SELECT #{select_clauses.kind_of?(::Array) ? select_clauses.join("") : select_clauses.to_s}",
            "FROM #{from_clauses}",
            (joins(self) unless joins(self).blank? ),
            ("WHERE #{where_clauses.join(" AND ")}" unless wheres.blank? ),
            ("GROUP BY #{group_clauses.join(', ')}" unless groupings.blank? ),
            ("HAVING #{having_clauses.join(', ')}" unless havings.blank? ),
            ("#{locked}" unless locked.blank? )

          build_query \
            "SELECT * FROM (#{subquery}) AS id_list",
            "ORDER BY #{aliased_orders(order_clauses)}",
            ("LIMIT #{taken}" unless taken.blank? ),
            ("OFFSET #{skipped}" unless skipped.blank? )
        else
          super
        end
      end

      def using_distinct_on?
        select_clauses.any? { |x| x =~ /DISTINCT ON/ }
      end

      def aliased_orders(orders)
        # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON, so we work around this
        # by wrapping the +sql+ string as a sub-select and ordering in that query.
        order = orders.join(', ').split(/,/).map { |s| s.strip }.reject(&:blank?)
        order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{'DESC' if s =~ /\bdesc$/i}" }.join(', ')
      end

      def supports_insert_with_returning?
        engine.postgresql_version >= 80200
      end
    end
  end
end
