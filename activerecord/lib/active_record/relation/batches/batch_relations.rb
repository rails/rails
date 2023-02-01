# frozen_string_literal: true

module ActiveRecord
  module Batches
    class BatchRelations
      include Enumerable

      attr_reader :relation, :batch_limit, :order, :limited_relation, :iterate_by
      attr_reader :remaining, :ids, :yielded_relation

      delegate :primary_key, :where, :limit_value, :table, :to_sql, :klass, :predicate_builder, to: :relation

      def initialize(of:, start:, finish:, relation:, order:, use_ranges:, load:)
        @relation = relation
        @batch_limit = [of, limit_value].compact.min
        @order = order

        @limited_relation = relation.reorder(batch_order).limit(batch_limit)
        @limited_relation = relation.send(:apply_limits, limited_relation, start, finish, order)
        @limited_relation.skip_query_cache! # Retaining the results in the query cache would undermine the point of batching

        empty_scope = to_sql == klass.unscoped.all.to_sql

        if load
          @iterate_by = :loading_records
        elsif (empty_scope && use_ranges != false) || use_ranges
          @iterate_by = :using_ranges
        else
          @iterate_by = :default
        end

        @remaining = limit_value
        @ids = nil
        @yielded_relation = nil
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
          @ids, @yielded_relation = iterate

          unless ids.empty? || primary_key_offset
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
          unless ids.empty?
            yielded_relation = batch_relation.where(primary_key => ids)
            yielded_relation.send(:load_records, records)
          end

          [ids, yielded_relation]
        end

        def iterate_using_ranges(batch_relation)
          ids = batch_relation.pluck(primary_key)
          finish = ids.last
          if finish
            yielded_relation = relation.send(:apply_finish_limit, batch_relation, finish, order)
            yielded_relation = yielded_relation.except(:limit, :order)
            yielded_relation.skip_query_cache!(false)
          end

          [ids, yielded_relation]
        end

        def iterate_default(batch_relation)
          ids = batch_relation.pluck(primary_key)
          yielded_relation = where(primary_key => ids) if ids.any?

          [ids, yielded_relation]
        end

        def batch_order
          table[primary_key].public_send(order)
        end

        def next_batch_relation
          batch_relation = limited_relation
          batch_relation = batch_relation.limit(remaining) if remaining_below_batch_limit?
          batch_relation = batch_relation.where(offset_from_previous_batch) if primary_key_offset

          batch_relation
        end

        def remaining_below_batch_limit?
          remaining && remaining < batch_limit
        end

        def primary_key_offset
          ids&.last
        end

        def finished?
          ids.size < batch_limit || remaining&.zero?
        end

        def offset_from_previous_batch
          predicate_builder[primary_key, primary_key_offset, order == :desc ? :lt : :gt]
        end
    end
  end
end
