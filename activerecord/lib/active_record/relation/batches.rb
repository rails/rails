
module ActiveRecord
  module Batches
    # Looping through a collection of records from the database
    # (using the +all+ method, for example) is very inefficient
    # since it will try to instantiate all the objects at once.
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
    # * <tt>:batch_size</tt> - Specifies the size of the batch. Default to 1000.
    # * <tt>:start</tt> - Specifies the starting point for the batch processing.
    # This is especially useful if you want multiple workers dealing with
    # the same processing queue. You can make worker 1 handle all the records
    # between id 0 and 10,000 and worker 2 handle from 10,000 and beyond
    # (by setting the +:start+ option on that worker).
    #
    #   # Let's process for a batch of 2000 records, skipping the first 2000 rows
    #   Person.find_each(start: 2000, batch_size: 2000) do |person|
    #     person.party_all_night!
    #   end
    #
    # NOTE: It's not possible to set the order. That is automatically set to
    # ascending on the primary key ("id ASC") to make the batch ordering
    # work. This also means that this method only works with integer-based
    # primary keys.
    #
    # NOTE: You can't set the limit either, that's used to control
    # the batch sizes.
    def find_each(options = {})
      if block_given?
        find_in_batches(options) do |records|
          records.each { |record| yield record }
        end
      else
        enum_for :find_each, options do
          options[:start] ? where(table[primary_key].gteq(options[:start])).size : size
        end
      end
    end

    # Yields each batch of records that was found by the find +options+ as
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
    # * <tt>:batch_size</tt> - Specifies the size of the batch. Default to 1000.
    # * <tt>:start</tt> - Specifies the starting point for the batch processing.
    # This is especially useful if you want multiple workers dealing with
    # the same processing queue. You can make worker 1 handle all the records
    # between id 0 and 10,000 and worker 2 handle from 10,000 and beyond
    # (by setting the +:start+ option on that worker).
    #
    #   # Let's process the next 2000 records
    #   Person.find_in_batches(start: 2000, batch_size: 2000) do |group|
    #     group.each { |person| person.party_all_night! }
    #   end
    #
    # NOTE: It's not possible to set the order. That is automatically set to
    # ascending on the primary key ("id ASC") to make the batch ordering
    # work. This also means that this method only works with integer-based
    # primary keys.
    #
    # NOTE: You can't set the limit either, that's used to control
    # the batch sizes.
    def find_in_batches(options = {})
      options.assert_valid_keys(:start, :batch_size)

      relation = self
      start = options[:start]
      batch_size = options[:batch_size] || 1000

      unless block_given?
        return to_enum(:find_in_batches, options) do
          total = start ? where(table[primary_key].gteq(start)).size : size
          (total - 1).div(batch_size) + 1
        end
      end

      if logger && (arel.orders.present? || arel.taken.present?)
        logger.warn("Scoped order and limit are ignored, it's forced to be batch order and batch size")
      end

      relation = relation.reorder(batch_order).limit(batch_size)
      records = start ? relation.where(table[primary_key].gteq(start)).to_a : relation.to_a

      while records.any?
        records_size = records.size
        primary_key_offset = records.last.id
        raise "Primary key not included in the custom select clause" unless primary_key_offset

        yield records

        break if records_size < batch_size

        records = relation.where(table[primary_key].gt(primary_key_offset)).to_a
      end
    end

    private

    def batch_order
      "#{quoted_table_name}.#{quoted_primary_key} ASC"
    end
  end
end
