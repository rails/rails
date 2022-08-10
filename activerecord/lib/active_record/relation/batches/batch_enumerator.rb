# frozen_string_literal: true

module ActiveRecord
  module Batches
    class BatchEnumerator
      include Enumerable

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

        @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: true, order: @order).each do |relation|
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
      def each(&block)
        enum = @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: false, order: @order, use_ranges: @use_ranges)
        return enum.each(&block) if block_given?
        enum
      end
    end
  end
end
