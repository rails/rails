require 'set'

module ActiveRecord
  module Associations
    class AssociationCollection < AssociationProxy #:nodoc:
      def to_ary
        load_target
        @target.to_ary
      end
  
      def reset
        @target = []
        @loaded = false
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.  
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def <<(*records)
        result = true
        load_target
        @owner.transaction do
          flatten_deeper(records).each do |record|
            raise_on_type_mismatch(record)
            result &&= insert_record(record) unless @owner.new_record?
            @target << record
          end
        end

        result and self
      end

      alias_method :push, :<<
      alias_method :concat, :<<

      # Remove +records+ from this association.  Does not destroy +records+.
      def delete(*records)
        records = flatten_deeper(records)
        records.each { |record| raise_on_type_mismatch(record) }
        records.reject! { |record| @target.delete(record) if record.new_record? }
        return if records.empty?
        
        @owner.transaction do
          delete_records(records)
          records.each { |record| @target.delete(record) }
        end
      end
      
      def destroy_all
        @owner.transaction do
          each { |record| record.destroy }
        end

        @target = []
      end
      
      def create(attributes = {})
        # Can't use Base.create since the foreign key may be a protected attribute.
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr) }
        else
          record = build(attributes)
          record.save unless @owner.new_record?
          record
        end
      end

      # Returns the size of the collection by executing a SELECT COUNT(*) query if the collection hasn't been loaded and
      # calling collection.size if it has. If it's more likely than not that the collection does have a size larger than zero
      # and you need to fetch that collection afterwards, it'll take one less SELECT query if you use length.
      def size
        if loaded? then @target.size else count_records end
      end
      
      # Returns the size of the collection by loading it and calling size on the array. If you want to use this method to check
      # whether the collection is empty, use collection.length.zero? instead of collection.empty?
      def length
        load_target.size
      end
      
      def empty?
        size.zero?
      end
      
      def uniq(collection = self)
        collection.inject([]) { |uniq_records, record| uniq_records << record unless uniq_records.include?(record); uniq_records }
      end

      # Replace this collection with +other_array+
      # This will perform a diff and delete/add only records that have changed.
      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch(val) }

        load_target
        other   = other_array.size < 100 ? other_array : other_array.to_set
        current = @target.size < 100 ? @target : @target.to_set

        @owner.transaction do
          delete(@target.select { |v| !other.include?(v) })
          concat(other_array.select { |v| !current.include?(v) })
        end
      end

      private
        def raise_on_type_mismatch(record)
          raise ActiveRecord::AssociationTypeMismatch, "#{@association_class} expected, got #{record.class}" unless record.is_a?(@association_class)
        end

        def target_obsolete?
          false
        end

        # Array#flatten has problems with recursive arrays. Going one level deeper solves the majority of the problems.
        def flatten_deeper(array)
          array.collect { |element| element.respond_to?(:flatten) ? element.flatten : element }.flatten
        end
    end
  end
end
