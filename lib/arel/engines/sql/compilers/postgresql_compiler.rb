module Arel
  module SqlCompiler
    class PostgreSQLCompiler < GenericCompiler

      def select_sql
        if !relation.orders.blank? && using_distinct_on?
          selects = relation.select_clauses
          joins   = relation.joins(self)
          wheres  = relation.where_clauses
          groups  = relation.group_clauses
          havings = relation.having_clauses
          orders  = relation.order_clauses

          subquery_clauses = [ "",
            "SELECT     #{selects.kind_of?(::Array) ? selects.join("") : selects.to_s}",
            "FROM       #{relation.from_clauses}",
            joins,
            ("WHERE     #{wheres.join(' AND ')}" unless wheres.empty?),
            ("GROUP BY  #{groups.join(', ')}" unless groups.empty?),
            ("HAVING    #{havings.join(' AND ')}" unless havings.empty?)
          ].compact.join ' '
          subquery_clauses << " #{locked}" unless locked.blank?

          build_query \
            "SELECT * FROM (#{build_query subquery_clauses}) AS id_list",
            "ORDER BY #{aliased_orders(orders)}",
            ("LIMIT #{relation.taken}" unless relation.taken.blank? ),
            ("OFFSET #{relation.skipped}" unless relation.skipped.blank? )
        else
          super
        end
      end

      def using_distinct_on?
        relation.select_clauses.any? { |x| x =~ /DISTINCT ON/ }
      end

      def aliased_orders(orders)
        # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON, so we work around this
        # by wrapping the +sql+ string as a sub-select and ordering in that query.
        order = orders.join(', ').split(/,/).map { |s| s.strip }.reject(&:blank?)
        order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{'DESC' if s =~ /\bdesc$/i}" }.join(', ')
      end

      def supports_insert_with_returning?
        engine.connection.send(:postgresql_version) >= 80200
      end
    end
  end
end
