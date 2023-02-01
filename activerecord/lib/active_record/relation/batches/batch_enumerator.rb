# frozen_string_literal: true

module ActiveRecord
  module Batches
    class BatchEnumerator
      include Enumerable

      delegate :arel, :limit_value, :table, :primary_key, :to_sql, :klass, :predicate_builder, :where, to: :relation

      def initialize(of: 1000, start: nil, finish: nil, relation:, order: :asc, use_ranges: nil) # :nodoc:
        @of       = of
        @relation = relation
        @start = start
        @finish = finish
        @order = order
        @use_ranges = use_ranges
      end

      # The primary key value from which the BatchEnumerator starts, inclusive of the value.
      attr_reader :start

      # The primary key value at which the BatchEnumerator ends, inclusive of the value.
      attr_reader :finish

      # The relation from which the BatchEnumerator yields batches.
      attr_reader :relation

      # The size of the batches yielded by the BatchEnumerator.
      def batch_size
        @of
      end

      # Looping through a collection of records from the database (using the
      # +all+ method, for example) is very inefficient since it will try to
      # instantiate all the objects at once.
      #
      # In that case, batch processing methods allow you to work with the
      # records in batches, thereby greatly reducing memory consumption.
      #
      #   Person.in_batches.each_record do |person|
      #     person.do_awesome_stuff
      #   end
      #
      #   Person.where("age > 21").in_batches(of: 10).each_record do |person|
      #     person.party_all_night!
      #   end
      #
      # If you do not provide a block to #each_record, it will return an Enumerator
      # for chaining with other methods:
      #
      #   Person.in_batches.each_record.with_index do |person, index|
      #     person.award_trophy(index + 1)
      #   end
      def each_record(&block)
        return to_enum(:each_record) unless block_given?

        each(load: true) do |relation|
          relation.records.each(&block)
        end
      end

      # Deletes records in batches. Returns the total number of rows affected.
      #
      #   Person.in_batches.delete_all
      #
      # See Relation#delete_all for details of how each batch is deleted.
      def delete_all
        sum(&:delete_all)
      end

      # Updates records in batches. Returns the total number of rows affected.
      #
      #   Person.in_batches.update_all("age = age + 1")
      #
      # See Relation#update_all for details of how each batch is updated.
      def update_all(updates)
        sum do |relation|
          relation.update_all(updates)
        end
      end

      # Destroys records in batches.
      #
      #   Person.where("age < 10").in_batches.destroy_all
      #
      # See Relation#destroy_all for details of how each batch is destroyed.
      def destroy_all
        each(&:destroy_all)
      end

      # Yields an ActiveRecord::Relation object for each batch of records.
      #
      #   Person.in_batches.each do |relation|
      #     relation.update_all(awesome: true)
      #   end
      def each(load: false, error_on_ignore: nil)
        return to_enum(:each) unless block_given?

        batch_limit = batch_size
        if limit_value
          remaining   = limit_value
          batch_limit = remaining if remaining < batch_limit
        end

        relation = @relation.reorder(batch_order(@order)).limit(batch_limit)
        relation = relation.send(:apply_limits, relation, start, finish, @order)
        relation.skip_query_cache! # Retaining the results in the query cache would undermine the point of batching
        batch_relation = relation
        empty_scope = to_sql == klass.unscoped.all.to_sql

        loop do
          if load
            records = batch_relation.records
            ids = records.map(&:id)
            yielded_relation = where(primary_key => ids)
            yielded_relation.send(:load_records, records)
          elsif (empty_scope && @use_ranges != false) || @use_ranges
            ids = batch_relation.pluck(primary_key)
            finish = ids.last
            if finish
              yielded_relation = relation.send(:apply_finish_limit, batch_relation, finish, @order)
              yielded_relation = yielded_relation.except(:limit, :order)
              yielded_relation.skip_query_cache!(false)
            end
          else
            ids = batch_relation.pluck(primary_key)
            yielded_relation = where(primary_key => ids)
          end

          break if ids.empty?

          primary_key_offset = ids.last
          raise ArgumentError.new("Primary key not included in the custom select clause") unless primary_key_offset

          yield yielded_relation

          break if ids.length < batch_limit

          if limit_value
            remaining -= ids.length

            if remaining == 0
              # Saves a useless iteration when the limit is a multiple of the
              # batch size.
              break
            elsif remaining < batch_limit
              relation = relation.limit(remaining)
            end
          end

          batch_relation = relation.where(
            predicate_builder[primary_key, primary_key_offset, @order == :desc ? :lt : :gt]
          )
        end
      end

      private
        def batch_order(order)
          table[primary_key].public_send(order)
        end
    end
  end
end
