# frozen_string_literal: true

require "active_record/relation/batches/batch_enumerator"

module ActiveRecord
  # = Active Record \Batches
  module Batches
    ORDER_IGNORE_MESSAGE = "Scoped order is ignored, use :cursor with :order to configure custom order."
    DEFAULT_ORDER = :asc

    # Looping through a collection of records from the database
    # (using the Scoping::Named::ClassMethods.all method, for example)
    # is very inefficient since it will try to instantiate all the objects at once.
    #
    # In that case, batch processing methods allow you to work
    # with the records in batches, thereby greatly reducing memory consumption.
    #
    # The #find_each method uses #find_in_batches with a batch size of 1000 (or as
    # specified by the +:batch_size+ option).
    #
    #   Person.find_each do |person|
    #     person.do_awesome_stuff
    #   end
    #
    #   Person.where("age > 21").find_each do |person|
    #     person.party_all_night!
    #   end
    #
    # If you do not provide a block to #find_each, it will return an Enumerator
    # for chaining with other methods:
    #
    #   Person.find_each.with_index do |person, index|
    #     person.award_trophy(index + 1)
    #   end
    #
    # ==== Options
    # * <tt>:batch_size</tt> - Specifies the size of the batch. Defaults to 1000.
    # * <tt>:start</tt> - Specifies the cursor column value to start from, inclusive of the value.
    # * <tt>:finish</tt> - Specifies the cursor column value to end at, inclusive of the value.
    # * <tt>:error_on_ignore</tt> - Overrides the application config to specify if an error should be raised when
    #   an order is present in the relation.
    # * <tt>:cursor</tt> - Specifies the column to use for batching (can be a column name or an array
    #   of column names). Defaults to primary key.
    # * <tt>:order</tt> - Specifies the cursor column order (can be +:asc+ or +:desc+ or an array consisting
    #   of :asc or :desc). Defaults to +:asc+.
    #
    #     class Order < ActiveRecord::Base
    #       self.primary_key = [:id_1, :id_2]
    #     end
    #
    #     Order.find_each(order: [:asc, :desc])
    #
    #   In the above code, +id_1+ is sorted in ascending order and +id_2+ in descending order.
    #
    # Limits are honored, and if present there is no requirement for the batch
    # size: it can be less than, equal to, or greater than the limit.
    #
    # The options +start+ and +finish+ are especially useful if you want
    # multiple workers dealing with the same processing queue. You can make
    # worker 1 handle all the records between id 1 and 9999 and worker 2
    # handle from 10000 and beyond by setting the +:start+ and +:finish+
    # option on each worker.
    #
    #   # In worker 1, let's process until 9999 records.
    #   Person.find_each(finish: 9_999) do |person|
    #     person.party_all_night!
    #   end
    #
    #   # In worker 2, let's process from record 10_000 and onwards.
    #   Person.find_each(start: 10_000) do |person|
    #     person.party_all_night!
    #   end
    #
    # NOTE: Order can be ascending (:asc) or descending (:desc). It is automatically set to
    # ascending on the primary key ("id ASC").
    # This also means that this method only works when the cursor column is
    # orderable (e.g. an integer or string).
    #
    # NOTE: When using custom columns for batching, they should include at least one unique column
    # (e.g. primary key) as a tiebreaker. Also, to reduce the likelihood of race conditions,
    # all columns should be static (unchangeable after it was set).
    #
    # NOTE: By its nature, batch processing is subject to race conditions if
    # other processes are modifying the database.
    def find_each(start: nil, finish: nil, batch_size: 1000, error_on_ignore: nil, cursor: primary_key, order: DEFAULT_ORDER, &block)
      if block_given?
        find_in_batches(start: start, finish: finish, batch_size: batch_size, error_on_ignore: error_on_ignore, cursor: cursor, order: order) do |records|
          records.each(&block)
        end
      else
        enum_for(:find_each, start: start, finish: finish, batch_size: batch_size, error_on_ignore: error_on_ignore, cursor: cursor, order: order) do
          relation = self
          cursor = Array(cursor)
          apply_limits(relation, cursor, start, finish, build_batch_orders(cursor, order)).size
        end
      end
    end

    # Yields each batch of records that was found by the find options as
    # an array.
    #
    #   Person.where("age > 21").find_in_batches do |group|
    #     sleep(50) # Make sure it doesn't get too crowded in there!
    #     group.each { |person| person.party_all_night! }
    #   end
    #
    # If you do not provide a block to #find_in_batches, it will return an Enumerator
    # for chaining with other methods:
    #
    #   Person.find_in_batches.with_index do |group, batch|
    #     puts "Processing group ##{batch}"
    #     group.each(&:recover_from_last_night!)
    #   end
    #
    # To be yielded each record one by one, use #find_each instead.
    #
    # ==== Options
    # * <tt>:batch_size</tt> - Specifies the size of the batch. Defaults to 1000.
    # * <tt>:start</tt> - Specifies the cursor column value to start from, inclusive of the value.
    # * <tt>:finish</tt> - Specifies the cursor column value to end at, inclusive of the value.
    # * <tt>:error_on_ignore</tt> - Overrides the application config to specify if an error should be raised when
    #   an order is present in the relation.
    # * <tt>:cursor</tt> - Specifies the column to use for batching (can be a column name or an array
    #   of column names). Defaults to primary key.
    # * <tt>:order</tt> - Specifies the cursor column order (can be +:asc+ or +:desc+ or an array consisting
    #   of :asc or :desc). Defaults to +:asc+.
    #
    #     class Order < ActiveRecord::Base
    #       self.primary_key = [:id_1, :id_2]
    #     end
    #
    #     Order.find_in_batches(order: [:asc, :desc])
    #
    #   In the above code, +id_1+ is sorted in ascending order and +id_2+ in descending order.
    #
    # Limits are honored, and if present there is no requirement for the batch
    # size: it can be less than, equal to, or greater than the limit.
    #
    # The options +start+ and +finish+ are especially useful if you want
    # multiple workers dealing with the same processing queue. You can make
    # worker 1 handle all the records between id 1 and 9999 and worker 2
    # handle from 10000 and beyond by setting the +:start+ and +:finish+
    # option on each worker.
    #
    #   # Let's process from record 10_000 on.
    #   Person.find_in_batches(start: 10_000) do |group|
    #     group.each { |person| person.party_all_night! }
    #   end
    #
    # NOTE: Order can be ascending (:asc) or descending (:desc). It is automatically set to
    # ascending on the primary key ("id ASC").
    # This also means that this method only works when the cursor column is
    # orderable (e.g. an integer or string).
    #
    # NOTE: When using custom columns for batching, they should include at least one unique column
    # (e.g. primary key) as a tiebreaker. Also, to reduce the likelihood of race conditions,
    # all columns should be static (unchangeable after it was set).
    #
    # NOTE: By its nature, batch processing is subject to race conditions if
    # other processes are modifying the database.
    def find_in_batches(start: nil, finish: nil, batch_size: 1000, error_on_ignore: nil, cursor: primary_key, order: DEFAULT_ORDER)
      relation = self
      unless block_given?
        return to_enum(:find_in_batches, start: start, finish: finish, batch_size: batch_size, error_on_ignore: error_on_ignore, cursor: cursor, order: order) do
          cursor = Array(cursor)
          total = apply_limits(relation, cursor, start, finish, build_batch_orders(cursor, order)).size
          (total - 1).div(batch_size) + 1
        end
      end

      in_batches(of: batch_size, start: start, finish: finish, load: true, error_on_ignore: error_on_ignore, cursor: cursor, order: order) do |batch|
        yield batch.to_a
      end
    end

    # Yields ActiveRecord::Relation objects to work with a batch of records.
    #
    #   Person.where("age > 21").in_batches do |relation|
    #     relation.delete_all
    #     sleep(10) # Throttle the delete queries
    #   end
    #
    # If you do not provide a block to #in_batches, it will return a
    # BatchEnumerator which is enumerable.
    #
    #   Person.in_batches.each_with_index do |relation, batch_index|
    #     puts "Processing relation ##{batch_index}"
    #     relation.delete_all
    #   end
    #
    # Examples of calling methods on the returned BatchEnumerator object:
    #
    #   Person.in_batches.delete_all
    #   Person.in_batches.update_all(awesome: true)
    #   Person.in_batches.each_record(&:party_all_night!)
    #
    # ==== Options
    # * <tt>:of</tt> - Specifies the size of the batch. Defaults to 1000.
    # * <tt>:load</tt> - Specifies if the relation should be loaded. Defaults to false.
    # * <tt>:start</tt> - Specifies the cursor column value to start from, inclusive of the value.
    # * <tt>:finish</tt> - Specifies the cursor column value to end at, inclusive of the value.
    # * <tt>:error_on_ignore</tt> - Overrides the application config to specify if an error should be raised when
    #   an order is present in the relation.
    # * <tt>:cursor</tt> - Specifies the column to use for batching (can be a column name or an array
    #   of column names). Defaults to primary key.
    # * <tt>:order</tt> - Specifies the cursor column order (can be +:asc+ or +:desc+ or an array consisting
    #   of :asc or :desc). Defaults to +:asc+.
    #
    #     class Order < ActiveRecord::Base
    #       self.primary_key = [:id_1, :id_2]
    #     end
    #
    #     Order.in_batches(order: [:asc, :desc])
    #
    #   In the above code, +id_1+ is sorted in ascending order and +id_2+ in descending order.
    #
    # * <tt>:use_ranges</tt> - Specifies whether to use range iteration (id >= x AND id <= y).
    #   It can make iterating over the whole or almost whole tables several times faster.
    #   Only whole table iterations use this style of iteration by default. You can disable this behavior by passing +false+.
    #   If you iterate over the table and the only condition is, e.g., <tt>archived_at: nil</tt> (and only a tiny fraction
    #   of the records are archived), it makes sense to opt in to this approach.
    #
    # Limits are honored, and if present there is no requirement for the batch
    # size, it can be less than, equal, or greater than the limit.
    #
    # The options +start+ and +finish+ are especially useful if you want
    # multiple workers dealing with the same processing queue. You can make
    # worker 1 handle all the records between id 1 and 9999 and worker 2
    # handle from 10000 and beyond by setting the +:start+ and +:finish+
    # option on each worker.
    #
    #   # Let's process from record 10_000 on.
    #   Person.in_batches(start: 10_000).update_all(awesome: true)
    #
    # An example of calling where query method on the relation:
    #
    #   Person.in_batches.each do |relation|
    #     relation.update_all('age = age + 1')
    #     relation.where('age > 21').update_all(should_party: true)
    #     relation.where('age <= 21').delete_all
    #   end
    #
    # NOTE: If you are going to iterate through each record, you should call
    # #each_record on the yielded BatchEnumerator:
    #
    #   Person.in_batches.each_record(&:party_all_night!)
    #
    # NOTE: Order can be ascending (:asc) or descending (:desc). It is automatically set to
    # ascending on the primary key ("id ASC").
    # This also means that this method only works when the cursor column is
    # orderable (e.g. an integer or string).
    #
    # NOTE: When using custom columns for batching, they should include at least one unique column
    # (e.g. primary key) as a tiebreaker. Also, to reduce the likelihood of race conditions,
    # all columns should be static (unchangeable after it was set).
    #
    # NOTE: By its nature, batch processing is subject to race conditions if
    # other processes are modifying the database.
    def in_batches(of: 1000, start: nil, finish: nil, load: false, error_on_ignore: nil, cursor: primary_key, order: DEFAULT_ORDER, use_ranges: nil, &block)
      cursor = Array(cursor).map(&:to_s)
      ensure_valid_options_for_batching!(cursor, start, finish, order)

      if arel.orders.present?
        act_on_ignored_order(error_on_ignore)
      end

      unless block
        return BatchEnumerator.new(of: of, start: start, finish: finish, relation: self, cursor: cursor, order: order, use_ranges: use_ranges)
      end

      batch_limit = of

      if limit_value
        remaining   = limit_value
        batch_limit = remaining if remaining < batch_limit
      end

      if self.loaded?
        batch_on_loaded_relation(
          relation: self,
          start: start,
          finish: finish,
          cursor: cursor,
          order: order,
          batch_limit: batch_limit,
          &block
        )
      else
        batch_on_unloaded_relation(
          relation: self,
          start: start,
          finish: finish,
          load: load,
          cursor: cursor,
          order: order,
          use_ranges: use_ranges,
          remaining: remaining,
          batch_limit: batch_limit,
          &block
        )
      end
    end

    private
      def ensure_valid_options_for_batching!(cursor, start, finish, order)
        if start && Array(start).size != cursor.size
          raise ArgumentError, ":start must contain one value per cursor column"
        end

        if finish && Array(finish).size != cursor.size
          raise ArgumentError, ":finish must contain one value per cursor column"
        end

        if (Array(primary_key) - cursor).any?
          indexes = model.schema_cache.indexes(table_name)
          unique_index = indexes.find { |index| index.unique && index.where.nil? && (Array(index.columns) - cursor).empty? }

          unless unique_index
            raise ArgumentError, ":cursor must include a primary key or other unique column(s)"
          end
        end

        if (Array(order) - [:asc, :desc]).any?
          raise ArgumentError, ":order must be :asc or :desc or an array consisting of :asc or :desc, got #{order.inspect}"
        end
      end

      def apply_limits(relation, cursor, start, finish, batch_orders)
        relation = apply_start_limit(relation, cursor, start, batch_orders) if start
        relation = apply_finish_limit(relation, cursor, finish, batch_orders) if finish
        relation
      end

      def apply_start_limit(relation, cursor, start, batch_orders)
        operators = batch_orders.map do |_column, order|
          order == :desc ? :lteq : :gteq
        end
        batch_condition(relation, cursor, start, operators)
      end

      def apply_finish_limit(relation, cursor, finish, batch_orders)
        operators = batch_orders.map do |_column, order|
          order == :desc ? :gteq : :lteq
        end
        batch_condition(relation, cursor, finish, operators)
      end

      def batch_condition(relation, cursor, values, operators)
        cursor_positions = cursor.zip(Array(values), operators)

        first_clause_column, first_clause_value, operator = cursor_positions.pop
        where_clause = predicate_builder[first_clause_column, first_clause_value, operator]

        cursor_positions.reverse_each do |column_name, value, operator|
          where_clause = predicate_builder[column_name, value, operator == :lteq ? :lt : :gt].or(
            predicate_builder[column_name, value, :eq].and(where_clause)
          )
        end

        relation.where(where_clause)
      end

      def build_batch_orders(cursor, order)
        cursor.zip(Array(order)).map do |column, order_|
          [column, order_ || DEFAULT_ORDER]
        end
      end

      def act_on_ignored_order(error_on_ignore)
        raise_error = (error_on_ignore.nil? ? ActiveRecord.error_on_ignored_order : error_on_ignore)

        if raise_error
          raise ArgumentError.new(ORDER_IGNORE_MESSAGE)
        elsif model.logger
          model.logger.warn(ORDER_IGNORE_MESSAGE)
        end
      end

      def batch_on_loaded_relation(relation:, start:, finish:, cursor:, order:, batch_limit:)
        records = relation.to_a
        order = build_batch_orders(cursor, order).map(&:second)

        if start || finish
          records = records.filter do |record|
            values = record_cursor_values(record, cursor)

            (start.nil? || compare_values_for_order(values, Array(start), order) >= 0) &&
              (finish.nil? || compare_values_for_order(values, Array(finish), order) <= 0)
          end
        end

        records.sort! do |record1, record2|
          values1 = record_cursor_values(record1, cursor)
          values2 = record_cursor_values(record2, cursor)
          compare_values_for_order(values1, values2, order)
        end

        records.each_slice(batch_limit) do |subrecords|
          subrelation = relation.spawn
          subrelation.load_records(subrecords)

          yield subrelation
        end

        nil
      end

      def record_cursor_values(record, cursor)
        record.attributes.slice(*cursor).values
      end

      # This is a custom implementation of `<=>` operator,
      # which also takes into account how the collection will be ordered.
      def compare_values_for_order(values1, values2, order)
        values1.each_with_index do |element1, index|
          element2 = values2[index]
          direction = order[index]
          comparison = element1 <=> element2
          comparison = -comparison if direction == :desc
          return comparison if comparison != 0
        end

        0
      end

      def batch_on_unloaded_relation(relation:, start:, finish:, load:, cursor:, order:, use_ranges:, remaining:, batch_limit:)
        batch_orders = build_batch_orders(cursor, order)
        relation = relation.reorder(batch_orders.to_h).limit(batch_limit)
        relation = apply_limits(relation, cursor, start, finish, batch_orders)
        relation.skip_query_cache! # Retaining the results in the query cache would undermine the point of batching
        batch_relation = relation
        empty_scope = to_sql == model.unscoped.all.to_sql

        loop do
          if load
            records = batch_relation.records
            values = records.pluck(*cursor)
            yielded_relation = where(cursor => values).order(batch_orders.to_h)
            yielded_relation.load_records(records)
          elsif (empty_scope && use_ranges != false) || use_ranges
            values = batch_relation.pluck(*cursor)

            finish = values.last
            if finish
              yielded_relation = apply_finish_limit(batch_relation, cursor, finish, batch_orders)
              yielded_relation = yielded_relation.except(:limit).reorder(batch_orders.to_h)
              yielded_relation.skip_query_cache!(false)
            end
          else
            values = batch_relation.pluck(*cursor)
            yielded_relation = where(cursor => values).order(batch_orders.to_h)
          end

          break if values.empty?

          if values.flatten.any?(nil)
            raise ArgumentError, "Not all of the batch cursor columns were included in the custom select clause "\
                                  "or some columns contain nil."
          end

          yield yielded_relation

          break if values.length < batch_limit

          if limit_value
            remaining -= values.length

            if remaining == 0
              # Saves a useless iteration when the limit is a multiple of the
              # batch size.
              break
            elsif remaining < batch_limit
              relation = relation.limit(remaining)
            end
          end

          batch_orders_copy = batch_orders.dup
          _last_column, last_order = batch_orders_copy.pop
          operators = batch_orders_copy.map do |_column, order|
            order == :desc ? :lteq : :gteq
          end
          operators << (last_order == :desc ? :lt : :gt)

          cursor_value = values.last
          batch_relation = batch_condition(relation, cursor, cursor_value, operators)
        end

        nil
      end
  end
end
