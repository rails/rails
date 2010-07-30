module Arel
  module SqlCompiler
    class GenericCompiler
      attr_reader :relation, :engine

      def initialize(relation)
        @relation = relation
        @engine = relation.engine
      end

      def christener
        relation.christener
      end

      def select_sql
        projections = @relation.projections
        if Count === projections.first && projections.size == 1 &&
          (relation.taken.present? || relation.wheres.present?) && relation.joins(self).blank?
          subquery = [
            "SELECT 1 FROM #{relation.from_clauses}", build_clauses
          ].join ' '
          query = "SELECT COUNT(*) AS count_id FROM (#{subquery}) AS subquery"
        else
          query = [
            "SELECT     #{relation.select_clauses.join(', ')}",
            "FROM       #{relation.from_clauses}",
            build_clauses
          ].compact.join ' '
        end
        query
      end

      def build_clauses
        joins   = relation.joins(self)
        wheres  = relation.where_clauses
        groups  = relation.group_clauses
        havings = relation.having_clauses
        orders  = relation.order_clauses

        clauses = [ "",
          joins,
          ("WHERE     #{wheres.join(' AND ')}" unless wheres.empty?),
          ("GROUP BY  #{groups.join(', ')}" unless groups.empty?),
          ("HAVING    #{havings.join(' AND ')}" unless havings.empty?),
          ("ORDER BY  #{orders.join(', ')}" unless orders.empty?)
        ].compact.join ' '

        offset = relation.skipped
        limit = relation.taken
        @engine.connection.add_limit_offset!(clauses, :limit => limit,
                                  :offset => offset) if offset || limit

        clauses << " #{locked}" unless locked.blank?
        clauses unless clauses.blank?
      end

      def delete_sql
        build_query \
          "DELETE",
          "FROM #{relation.table_sql}",
          ("WHERE #{relation.wheres.collect { |x| x.to_sql }.join(' AND ')}" unless relation.wheres.blank? ),
          (add_limit_on_delete(relation.taken)                        unless relation.taken.blank?  )
      end

      def add_limit_on_delete(taken)
        "LIMIT #{taken}"
      end

      def insert_sql(include_returning = true)
        insertion_attributes_values_sql = if relation.record.is_a?(Value)
          relation.record.value
        else
          attributes = relation.record.keys.sort_by do |attribute|
            attribute.name.to_s
          end

          first = attributes.collect do |key|
            @engine.connection.quote_column_name(key.name)
          end.join(', ')

          second = attributes.collect do |key|
            key.format(relation.record[key])
          end.join(', ')

          build_query "(#{first})", "VALUES (#{second})"
        end

        build_query \
          "INSERT",
          "INTO #{relation.table_sql}",
          insertion_attributes_values_sql,
          ("RETURNING #{engine.connection.quote_column_name(primary_key)}" if include_returning && relation.compiler.supports_insert_with_returning?)
      end

      def supports_insert_with_returning?
        false
      end

      def update_sql
        build_query \
          "UPDATE #{relation.table_sql} SET",
          assignment_sql,
          build_update_conditions_sql
      end

      protected

      def locked
        relation.locked
      end

      def build_query(*parts)
        parts.compact.join(" ")
      end

      def assignment_sql
        if relation.assignments.respond_to?(:collect)
          attributes = relation.assignments.keys.sort_by do |attribute|
            attribute.name.to_s
          end

          attributes.map do |attribute|
            value = relation.assignments[attribute]
            "#{@engine.connection.quote_column_name(attribute.name)} = #{attribute.format(value)}"
          end.join(", ")
        else
          relation.assignments.value
        end
      end

      def build_update_conditions_sql
        conditions = ""
        conditions << " WHERE #{relation.wheres.map { |x| x.to_sql }.join(' AND ')}" unless relation.wheres.blank?
        conditions << " ORDER BY #{relation.order_clauses.join(', ')}" unless relation.orders.blank?

        taken = relation.taken
        unless taken.blank?
          conditions = limited_update_conditions(conditions, taken)
        end

        conditions
      end

      def limited_update_conditions(conditions, taken)
        conditions << " LIMIT #{taken}"
        quoted_primary_key = @engine.connection.quote_column_name(relation.primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{@engine.connection.quote_table_name relation.table.name} #{conditions})"
      end

    end

  end
end
