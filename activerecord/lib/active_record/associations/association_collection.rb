module ActiveRecord
  module Associations
    class AssociationCollection #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?|^proxy_respond_to\?)/ }

      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @owner = owner
        @options = options
        @association_name = association_name
        @association_class = eval(association_class_name)
        @association_class_primary_key_name = association_class_primary_key_name
      end
      
      def method_missing(symbol, *args, &block)
        load_collection
        @collection.send(symbol, *args, &block)
      end
  
      def to_ary
        load_collection
        @collection.to_ary
      end
  
      def respond_to?(symbol)
        proxy_respond_to?(symbol) || [].respond_to?(symbol)
      end

      def loaded?
        !@collection.nil?
      end
      
      def reload
        @collection = nil
      end

      # Add +records+ to this association.  Returns +self+ so method calls may be chained.  
      # Since << flattens its argument list and inserts each record, +push+ and +concat+ behave identically.
      def <<(*records)
        flatten_deeper(records).each do |record|
          raise_on_type_mismatch(record)
          insert_record(record)
          @collection << record if loaded?
        end
        self
      end

      alias_method :push, :<<
      alias_method :concat, :<<

      # Remove +records+ from this association.  Does not destroy +records+.
      def delete(*records)
        records = flatten_deeper(records)
        records.each { |record| raise_on_type_mismatch(record) }
        delete_records(records)
        records.each { |record| @collection.delete(record) } if loaded?
      end
      
      def destroy_all
        each { |record| record.destroy }
        @collection = []
      end
      
      def size
        if loaded? then @collection.size else count_records end
      end
      
      def empty?
        size == 0
      end
      
      def uniq(collection = self)
        collection.inject([]) { |uniq_records, record| uniq_records << record unless uniq_records.include?(record); uniq_records }
      end
      
      alias_method :length, :size

      protected
        def loaded?
          not @collection.nil?
        end

        def quoted_record_ids(records)
          records.map { |record| record.quoted_id }.join(',')
        end

        def interpolate_sql_options!(options, *keys)
          keys.each { |key| options[key] &&= interpolate_sql(options[key]) }
        end

        def interpolate_sql(sql, record = nil)
          @owner.send(:interpolate_sql, sql, record)
        end
      
      private
        def load_collection
          begin
            @collection = find_all_records unless loaded?
          rescue ActiveRecord::RecordNotFound
            @collection = []
          end
        end

        def raise_on_type_mismatch(record)
          raise ActiveRecord::AssociationTypeMismatch, "#{@association_class} expected, got #{record.class}" unless record.is_a?(@association_class)
        end


        def load_collection_to_array
          return unless @collection_array.nil? 
          begin
            @collection_array = find_all_records
          rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
            @collection_array = []
          end       
        end
        
        def duplicated_records_array(records)
          records = [records] unless records.is_a?(Array) || records.is_a?(ActiveRecord::Associations::AssociationCollection)
          records.dup
        end

        # Array#flatten has problems with rescursive arrays. Going one level deeper solves the majority of the problems.
        def flatten_deeper(array)
          array.collect { |element| element.respond_to?(:flatten) ? element.flatten : element }.flatten
        end
    end
  end
end