module Arel
  module SqlCompiler
    class GenericCompiler
      attr_reader :relation

      def initialize(relation)
        @relation = relation
        @engine = relation.engine
      end

      def select_sql
        if relation.projections.first.is_a?(Count) && relation.projections.size == 1 &&
          (taken.present? || wheres.present?) && joins(self).blank?
          subquery = build_query("SELECT 1 FROM #{from_clauses}", build_clauses)
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
        joins   = joins(self)
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
        @engine.add_limit_offset!(clauses, :limit => limit,
                                  :offset => offset) if offset || limit

        clauses << " #{locked}" unless locked.blank?
        clauses unless clauses.blank?
      end

      def delete_sql
        build_query \
          "DELETE",
          "FROM #{table_sql}",
          ("WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank? ),
          (add_limit_on_delete(taken)                        unless taken.blank?  )
      end

      def add_limit_on_delete(taken)
        "LIMIT #{taken}"
      end

      def insert_sql(include_returning = true)
        insertion_attributes_values_sql = if record.is_a?(Value)
          record.value
        else
          attributes = record.keys.sort_by do |attribute|
            attribute.name.to_s
          end

          first = attributes.collect do |key|
            engine.quote_column_name(key.name)
          end.join(', ')

          second = attributes.collect do |key|
            key.format(record[key])
          end.join(', ')

          build_query "(#{first})", "VALUES (#{second})"
        end

        build_query \
          "INSERT",
          "INTO #{table_sql}",
          insertion_attributes_values_sql,
          ("RETURNING #{engine.quote_column_name(primary_key)}" if include_returning && compiler.supports_insert_with_returning?)
      end

      def supports_insert_with_returning?
        false
      end

      def update_sql
        build_query \
          "UPDATE #{table_sql} SET",
          assignment_sql,
          build_update_conditions_sql
      end

    protected
      def method_missing(method, *args)
        if block_given?
          relation.send(method, *args)  { |*block_args| yield(*block_args) }
        else
          relation.send(method, *args)
        end
      end

      def build_query(*parts)
        parts.compact.join(" ")
      end

      def assignment_sql
        if assignments.respond_to?(:collect)
          attributes = assignments.keys.sort_by do |attribute|
            attribute.name.to_s
          end

          attributes.map do |attribute|
            value = assignments[attribute]
            "#{engine.quote_column_name(attribute.name)} = #{attribute.format(value)}"
          end.join(", ")
        else
          assignments.value
        end
      end

      def build_update_conditions_sql
        conditions = ""
        conditions << " WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank?
        conditions << " ORDER BY #{order_clauses.join(', ')}" unless orders.blank?

        unless taken.blank?
          conditions = limited_update_conditions(conditions, taken)
        end

        conditions
      end

      def limited_update_conditions(conditions, taken)
        conditions << " LIMIT #{taken}"
        quoted_primary_key = engine.quote_column_name(primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions})"
      end

    end

  end
end
