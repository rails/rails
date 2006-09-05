require 'set'

module ActiveRecord
  module Associations
    class AssociationCollection < AssociationProxy #:nodoc:
      def to_ary
        load_target
        @target.to_ary
      end
  
      def reset
        reset_target!
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
            callback(:before_add, record)
            result &&= insert_record(record) unless @owner.new_record?
            @target << record
            callback(:after_add, record)
          end
        end

        result && self
      end

      alias_method :push, :<<
      alias_method :concat, :<<
                      
      # Remove all records from this association
      def delete_all
        load_target
        delete(@target)
        reset_target!
      end

      # Calculate sum using SQL, not Enumerable
      def sum(*args, &block)
        calculate(:sum, *args, &block)
      end

      # Remove +records+ from this association.  Does not destroy +records+.
      def delete(*records)
        records = flatten_deeper(records)
        records.each { |record| raise_on_type_mismatch(record) }
        records.reject! { |record| @target.delete(record) if record.new_record? }
        return if records.empty?
        
        @owner.transaction do
          records.each { |record| callback(:before_remove, record) }
          delete_records(records)
          records.each do |record|
            @target.delete(record)
            callback(:after_remove, record)
          end
        end
      end

      # Removes all records from this association.  Returns +self+ so method calls may be chained.
      def clear
        return self if length.zero? # forces load_target if hasn't happened already

        if @reflection.options[:dependent] && @reflection.options[:dependent] == :delete_all
          destroy_all
        else          
          delete_all
        end

        self
      end
      
      def destroy_all
        @owner.transaction do
          each { |record| record.destroy }
        end

        reset_target!
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
        if loaded? && !@reflection.options[:uniq]
          @target.size
        elsif !loaded? && !@reflection.options[:uniq] && @target.is_a?(Array)
          unsaved_records = Array(@target.detect { |r| r.new_record? })
          unsaved_records.size + count_records
        else
          count_records
        end
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
        seen = Set.new
        collection.inject([]) do |kept, record|
          unless seen.include?(record.id)
            kept << record
            seen << record.id
          end
          kept
        end
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

      protected
        def reset_target!
          @target = Array.new
        end

        def find_target
          records =
            if @reflection.options[:finder_sql]
              @reflection.klass.find_by_sql(@finder_sql)
            else
              find(:all)
            end

          @reflection.options[:uniq] ? uniq(records) : records
        end

      private
        def callback(method, record)
          callbacks_for(method).each do |callback|
            case callback
              when Symbol
                @owner.send(callback, record)
              when Proc, Method
                callback.call(@owner, record)
              else
                if callback.respond_to?(method)
                  callback.send(method, @owner, record)
                else
                  raise ActiveRecordError, "Callbacks must be a symbol denoting the method to call, a string to be evaluated, a block to be invoked, or an object responding to the callback method."
                end
            end
          end
        end
        
        def callbacks_for(callback_name)
          full_callback_name = "#{callback_name}_for_#{@reflection.name}"
          @owner.class.read_inheritable_attribute(full_callback_name.to_sym) || []
        end
        
    end
  end
end
