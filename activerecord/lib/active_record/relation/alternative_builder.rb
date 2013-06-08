module ActiveRecord
  class AlternativeBuilder # :nodoc:
    def initialize(match_type, context, *queries)
      @builder = match_type == :negative ? NegativeBuilder.new(context, *queries) : PositiveBuilder.new(context, *queries)
    end

    def build
      @builder.build
    end

    class Builder
      attr_accessor :queries_bind_values, :queries_joins_values

      def initialize(context, *source_queries)
        @context, @source_queries = context, source_queries
        @queries_bind_values, @queries_joins_values = [], { includes: [],  joins: [], references: [] }
      end

      def build
        ActiveRecord::Base.connection.supports_statement_cache? ? with_statement_cache : without_statement_cache
      end

      private

        def queries
          @queries ||= @source_queries.map do |query|
            if String === query || Hash === query
              query = where(query)
            elsif Array === query
              query = where(*query)
            end

            queries_bind_values.concat(query.bind_values) if query.bind_values.any?
            queries_joins_values[:includes].concat(query.includes_values) if query.includes_values.any?
            queries_joins_values[:joins].concat(query.joins_values) if query.joins_values.any?
            queries_joins_values[:references].concat(query.references_values) if query.references_values.any?
            query.arel.constraints.reduce(:and)
          end
        end

        def uniq_queries_joins_values
          @uniq_queries_joins_values ||= queries_joins_values.each { |tables| tables.uniq }
        end

        def method_missing(method_name, *args, &block)
          @context.send(method_name, *args, &block)
        end

        def add_joins_to(relation)
          relation = relation.references(uniq_queries_joins_values[:references])
          relation = relation.includes(uniq_queries_joins_values[:includes])
          relation.joins(uniq_queries_joins_values[:joins])
        end

        def add_related_values_to(relation)
          relation.bind_values += queries_bind_values
          relation.includes_values += uniq_queries_joins_values[:includes]
          relation.joins_values += uniq_queries_joins_values[:joins]
          relation.references_values += uniq_queries_joins_values[:references]

          relation
        end
    end

    class PositiveBuilder < Builder
      private

        def with_statement_cache
          if queries && queries_bind_values.any?
            relation = where([queries.reduce(:or).to_sql, *queries_bind_values.map { |v| v[1] }])
          else
            relation = where(queries.reduce(:or).to_sql)
          end

          add_joins_to relation
        end

        def without_statement_cache
          relation = where(queries.reduce(:or))
          add_related_values_to relation
        end
    end

    class NegativeBuilder < Builder
      private

        def with_statement_cache
          if queries && queries_bind_values.any?
            relation = where.not([queries.reduce(:or).to_sql, *queries_bind_values.map { |v| v[1] }])
          else
            relation = where.not(queries.reduce(:or).to_sql)
          end

          add_joins_to relation
        end

        def without_statement_cache
          relation = where.not(queries.reduce(:or))
          add_related_values_to relation
        end
    end
  end
end

