# frozen_string_literal: true

module ActiveRecord
  module Batches
    class BatchRelations
      include Enumerable

      attr_reader :relation, :batch_limit, :orderings, :order_columns, :limited_relation, :iterate_by
      attr_reader :primary_key_column, :primary_key_order_only, :primary_key_position
      attr_reader :remaining, :ids, :yielded_relation, :offsets

      delegate :primary_key, :where, :limit_value, :table, :to_sql, :klass, :predicate_builder, :connection, :arel_table, to: :relation

      def initialize(of:, start:, finish:, relation:, order:, use_ranges:, load:)
        @relation = relation
        @batch_limit = [of, limit_value].compact.min
        @orderings = order
        @order_columns = order.map(&:expr)

        @limited_relation = relation.reorder(orderings).limit(batch_limit)
        @limited_relation = relation.send(:apply_limits, limited_relation, start, finish, orderings)
        @limited_relation.skip_query_cache! # Retaining the results in the query cache would undermine the point of batching

        empty_scope = to_sql == klass.unscoped.all.to_sql

        @primary_key_column = relation.send(:arel_column, primary_key)
        @primary_key_order_only = order_columns == [primary_key_column]
        @primary_key_position = order_columns.index(primary_key_column)

        if load
          @iterate_by = :loading_records
        elsif primary_key_order_only && (empty_scope && use_ranges != false) || use_ranges
          @iterate_by = :using_ranges
        else
          @iterate_by = :default
        end

        # Mutated as we iterate
        @remaining = limit_value
        @ids = nil
        @yielded_relation = nil
        @offsets = nil
      end

      def each
        loop do
          next_iteration

          yield yielded_relation if yielded_relation

          break if finished?
        end
      end

      private
        def next_iteration
          @ids, @yielded_relation, @offsets = iterate

          if ids.present? && ids.last.nil?
            raise ArgumentError.new("Primary key not included in the custom select clause")
          end

          @remaining -= ids.size if remaining
        end

        def iterate
          case iterate_by
          when :loading_records
            iterate_loading_records(next_batch_relation)
          when :using_ranges
            iterate_using_ranges(next_batch_relation)
          else
            iterate_default(next_batch_relation)
          end
        end

        def iterate_loading_records(batch_relation)
          records = batch_relation.records
          ids = records.map(&:id)
          if ids.present?
            if primary_key_order_only
              offsets = [records.last.id]
            else
              offsets = Array(batch_relation.where(primary_key => ids.last).pick(*order_columns))
            end
            yielded_relation = batch_relation.where(primary_key => ids)
            yielded_relation.send(:load_records, records)
          end

          [ids, yielded_relation, offsets]
        end

        def iterate_using_ranges(batch_relation)
          ids = batch_relation.pluck(primary_key)
          finish = ids.last
          if finish
            yielded_relation = relation.send(:apply_finish_limit, batch_relation, finish, orderings)
            yielded_relation = yielded_relation.except(:limit, :order)
            yielded_relation.skip_query_cache!(false)
          end
          offsets = [*ids.last]

          [ids, yielded_relation, offsets]
        end

        def iterate_default(batch_relation)
          order_value_rows = batch_relation.pluck(*order_columns)
          ids = primary_key_order_only ? order_value_rows : order_value_rows.map { |row| row[primary_key_position] }
          if order_value_rows.present?
            offsets = Array(order_value_rows.last)
            yielded_relation = where(primary_key => ids)
          end

          [ids, yielded_relation, offsets]
        end

        def next_batch_relation
          batch_relation = limited_relation
          batch_relation = batch_relation.limit(remaining) if remaining_below_batch_limit?
          batch_relation = batch_relation.where(offset_clause) if offsets

          batch_relation
        end

        def remaining_below_batch_limit?
          remaining && remaining < batch_limit
        end

        def finished?
          ids.size < batch_limit || remaining&.zero?
        end

        def offset_clause
          if orderings.size == 1
            offset_from_single_column(orderings.first, offsets.first)
          else
            offset_from_multiple_columns
          end
        end

        def offset_from_single_column(ordering, offset)
          predicate_builder[ordering.expr.name, offset, ordering.ascending? ? :gt : :lt]
        end

        def offset_from_multiple_columns
          OffsetFromMany.new(orderings, offsets, primary_key_column, connection.sorts_nulls_first?, arel_table, predicate_builder).clause
        end

        class OffsetFromMany
          attr_reader :order_offsets, :primary_key_column, :arel_table, :predicate_builder

          def initialize(orderings, offsets, primary_key_column, sorts_nulls_first, arel_table, predicate_builder)
            @order_offsets = orderings.zip(offsets)
            @primary_key_column = primary_key_column
            @sorts_nulls_first = sorts_nulls_first
            @arel_table = arel_table
            @predicate_builder = predicate_builder
          end

          def clause
            order_offsets.size.times \
              .filter_map { |index| subsequent_to_many(index) } \
              .reduce(&:or)
          end

          private
            def subsequent_to_many(index)
              subsequent_clause = subsequent_to(*order_offsets[index])

              if subsequent_clause.nil?
                nil
              elsif index == 0
                subsequent_clause
              else
                equal_clauses = order_offsets[0..index - 1].map { |order_offset| equal_to(*order_offset) }
                arel_table.grouping([*equal_clauses, *subsequent_clause].reduce(&:and))
              end
            end

            def sorts_nulls_first?
              @sorts_nulls_first
            end

            def equal_to(ordering, offset)
              column = ordering.expr
              if offset
                predicate_builder_for(column)[column.name, offset, :eq]
              else
                column.eq(offset)
              end
            end

            def subsequent_to(ordering, offset)
              if offset.nil?
                subsequent_to_nil(ordering)
              else
                subsequent_to_value(ordering, offset)
              end
            end

            def subsequent_to_nil(ordering)
              if sorts_nulls_first? == ordering.ascending?
                # after null == NOT NULL
                ordering.expr.not_eq(nil)
              else
                # after null is an empty set, so the whole clause is redundant
                nil
              end
            end

            def subsequent_to_value(ordering, value)
              column = ordering.expr

              next_values = predicate_builder_for(column)[column.name, value, ordering.ascending? ? :gt : :lt]

              if column == primary_key_column || sorts_nulls_first? == ordering.ascending?
                next_values
              else
                # nulls are after our value, so we also need to match them
                arel_table.grouping(next_values.or(column.eq(nil)))
              end
            end

            def predicate_builder_for(column)
              column.relation.instance_variable_get("@klass").predicate_builder
            end
        end
    end
  end
end
