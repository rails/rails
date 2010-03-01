module Arel
  module SqlCompiler
    class OracleCompiler < GenericCompiler

      def select_sql
        where_clauses_array = where_clauses
        if limit_or_offset = !taken.blank? || !skipped.blank?
          # if need to select first records without ORDER BY and GROUP BY
          # then can use simple ROWNUM in WHERE clause
          if skipped.blank? && groupings.blank? && orders.blank?
            where_clauses_array << "ROWNUM <= #{taken}" if !taken.blank? && skipped.blank? && groupings.blank? && orders.blank?
            limit_or_offset = false
          end
        end

        # when limit or offset subquery is used then cannot use FOR UPDATE directly
        # and need to construct separate subquery for primary key
        if use_subquery_for_lock = limit_or_offset && !locked.blank?
          quoted_primary_key = engine.quote_column_name(primary_key)
        end
        select_attributes_string = use_subquery_for_lock ? quoted_primary_key : select_clauses.join(', ')

        # OracleEnhanced adapter workaround when ORDER BY is used with columns not
        # present in DISTINCT columns list
        order_clauses_array = if select_attributes_string =~ /DISTINCT.*FIRST_VALUE/ && !orders.blank?
          order = order_clauses.join(', ').split(',').map { |s| s.strip }.reject(&:blank?)
          order = order.zip((0...order.size).to_a).map { |s,i| "alias_#{i}__ #{'DESC' if s =~ /\bdesc$/i}" }
        else
          order_clauses
        end

        query = build_query \
          "SELECT     #{select_attributes_string}",
          "FROM       #{from_clauses}",
          (joins(self)                                   unless joins(self).blank? ),
          ("WHERE     #{where_clauses_array.join(" AND ")}"    unless where_clauses_array.blank?      ),
          ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   ),
          ("HAVING    #{having_clauses.join(', ')}"      unless havings.blank?     ),
          ("ORDER BY  #{order_clauses_array.join(', ')}" unless order_clauses_array.blank? )

        # Use existing method from oracle_enhanced adapter to implement limit and offset using subqueries
        engine.add_limit_offset!(query, :limit => taken, :offset => skipped) if limit_or_offset

        if use_subquery_for_lock
          build_query \
            "SELECT     #{select_clauses.join(', ')}",
            "FROM       #{from_clauses}",
            "WHERE      #{quoted_primary_key} IN (#{query})",
            "#{locked}"
        elsif !locked.blank?
          build_query query, "#{locked}"
        else
          query
        end
      end

      def delete_sql
        where_clauses_array = wheres.collect(&:to_sql)
        where_clauses_array << "ROWNUM <= #{taken}" unless taken.blank?
        build_query \
          "DELETE",
          "FROM #{table_sql}",
          ("WHERE #{where_clauses_array.join(' AND ')}" unless where_clauses_array.blank? )
      end

    protected

      def build_update_conditions_sql
        conditions = ""
        where_clauses_array = wheres.collect(&:to_sql)
        # if need to select first records without ORDER BY
        # then can use simple ROWNUM in WHERE clause
        if !taken.blank? && orders.blank?
          where_clauses_array << "ROWNUM <= #{taken}"
        end
        conditions << " WHERE #{where_clauses_array.join(' AND ')}" unless where_clauses_array.blank?
        unless taken.blank?
          conditions = limited_update_conditions(conditions, taken)
        end
        conditions
      end

      def limited_update_conditions(conditions, taken)
        # need to add ORDER BY only if just taken ones should be updated
        conditions << " ORDER BY #{order_clauses.join(', ')}" unless orders.blank?
        quoted_primary_key = engine.quote_column_name(primary_key)
        subquery = "SELECT #{quoted_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions}"
        # Use existing method from oracle_enhanced adapter to get taken records when ORDER BY is used
        engine.add_limit_offset!(subquery, :limit => taken) unless orders.blank?
        "WHERE #{quoted_primary_key} IN (#{subquery})"
      end

    end
  end
end
