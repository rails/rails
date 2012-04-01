require 'active_support/core_ext/object/blank'

module ActiveRecord
  module Batches
    # Yields each record that was found by the find +options+. The find is
    # performed by find_in_batches with a batch size of 1000 (or as
    # specified by the <tt>:batch_size</tt> option).
    #
    # Example:
    #
    #   Person.where("age > 21").find_each do |person|
    #     person.party_all_night!
    #   end
    #
    # Note: This method is only intended to use for batch processing of
    # large amounts of records that wouldn't fit in memory all at once. If
    # you just need to loop over less than 1000 records, it's probably
    # better just to use the regular find methods.
    def find_each(options = {})
      find_in_batches(options) do |records|
        records.each { |record| yield record }
      end
    end

    # Yields each batch of records that was found by the find +options+ as
    # an array. The size of each batch is set by the <tt>:batch_size</tt>
    # option; the default is 1000.
    #
    # You can control the starting point for the batch processing by
    # supplying the <tt>:start</tt> option. The id of the first element 
    # in the first batch will equal this value if such a record exists
    # (or the record with the next lowest id).
    #
    # You can limit the total number of records returned across all batches 
    # by supplying the <tt>:max_records</tt> option. This used with 
    # the start option above is especially useful if you
    # want multiple workers dealing with the same processing queue. You can
    # make worker 1 handle all the records between id 0 and 10,000 and
    # worker 2 handle from 10,000 and beyond (by setting the 
    # <tt>:max_records</tt> to 10,000 on each worker, and the 
    # <tt>:start</tt> option for the second worker).
    #
    # Note: the <tt>:max_records</tt> limits the number of records 
    # returned. So if you are trying to divide up your record space
    # you will need to find the correct offsets.
    #
    # It's not possible to set the order. That is automatically set to
    # ascending on the primary key ("id ASC") to make the batch ordering
    # work. This also mean that this method only works with integer-based
    # primary keys. You can't set the limit either, that's used to control
    # the batch sizes.
    #
    # Example:
    #
    #   Person.where("age > 21").find_in_batches do |group|
    #     sleep(50) # Make sure it doesn't get too crowded in there!
    #     group.each { |person| person.party_all_night! }
    #   end
    #
    #   Person.where("age > 21").find_in_batches(:batch_size => 10) do |group| 
    #     puts group.class # Array
    #     puts group.size # 10
    #   end 
    #
    #   puts Person.count # 10000
    #   batch_count
    #   Person.where("age > 21").find_in_batches(:max_records => 5000) do |group|
    #     # default batch size 1000
    #     batch_count += 1
    #   end 
    #   puts batch_count # 5
    #
    def find_in_batches(options = {})
      relation = self

      unless arel.orders.blank? && arel.taken.blank?
        ActiveRecord::Base.logger.warn("Scoped order and limit are ignored, it's forced to be batch order and batch size")
      end

      if (finder_options = options.except(:start, :batch_size, :max_records)).present?
        raise "You can't specify an order, it's forced to be #{batch_order}" if options[:order].present?
        raise "You can't specify a limit, it's forced to be the batch_size. See max_records"  if options[:limit].present?

        relation = apply_finder_options(finder_options)
      end

      start = options.delete(:start).to_i
      batch_size = options.delete(:batch_size) || 1000
      remaining_record_limit = options.delete(:max_records) 
      batch_size = [batch_size, remaining_record_limit].min if remaining_record_limit

      relation = relation.reorder(batch_order).limit(batch_size)
      records = relation.where(table[primary_key].gteq(start)).all

      while records.any?
        records_size = records.size
        primary_key_offset = records.last.id
        remaining_record_limit -= records_size if remaining_record_limit

        yield records

        break if records_size < batch_size || (remaining_record_limit && remaining_record_limit <= 0)

        if primary_key_offset
          records = relation.where(table[primary_key].gt(primary_key_offset))
          if remaining_record_limit && remaining_record_limit < batch_size
            records = records.limit(remaining_record_limit)
          end 
          records = records.to_a
        else
          raise "Primary key not included in the custom select clause"
        end
      end
    end

    private

    def batch_order
      "#{quoted_table_name}.#{quoted_primary_key} ASC"
    end
  end
end
