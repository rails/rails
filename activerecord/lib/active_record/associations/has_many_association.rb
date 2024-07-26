module ActiveRecord
  module Associations
    class HasManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @conditions = options[:conditions]
        
        if options[:finder_sql]
          @counter_sql = options[:finder_sql].gsub(/SELECT (.*) FROM/, "SELECT COUNT(*) FROM")
          @finder_sql = options[:finder_sql]
        else
          @counter_sql = "#{@association_class_primary_key_name} = '#{@owner.id}'#{@conditions ? " AND " + @conditions : ""}"
          @finder_sql = "#{@association_class_primary_key_name} = '#{@owner.id}' #{@conditions ? " AND " + @conditions : ""}"   
        end
      end
      
      def <<(record)
        raise ActiveRecord::AssociationTypeMismatch unless @association_class === record
        record.send(@association_class_primary_key_name + "=", @owner.id)
        record.save(false)
        @collection_array << record unless @collection_array.nil?
      end
 
      def delete(records)
        duplicated_records_array(records).each do |record|
          next if record.send(@association_class_primary_key_name) != @owner.id
          record.send(@association_class_primary_key_name + "=", nil)
          record.save(false)
          @collection_array.delete(record) unless @collection_array.nil?
        end
      end
      
      def create(attributes = {})
        # We can't use the regular Base.create method as the foreign key might be a protected attribute, hence the repetion
        record = @association_class.new(attributes || {})
        record.send(@association_class_primary_key_name + "=", @owner.id)
        record.save

        @collection_array << record unless @collection_array.nil?
        
        return record
      end

      def build(attributes = {})
        association = @association_class.new
        association.attributes = attributes.merge({ "#{@association_class_primary_key_name}" => @owner.id})
        association
      end
      
      def find_all(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil, &block)
        if block_given? || @options[:finder_sql]
          load_collection_to_array
          @collection_array.send(:find_all, &block)
        else
          @association_class.find_all(
              "#{@association_class_primary_key_name} = '#{@owner.id}' " +
              "#{@conditions ? " AND " + @conditions : ""} #{runtime_conditions ? " AND " + runtime_conditions : ""}",
              orderings, 
              limit, 
              joins
            )
        end
      end

      def find(association_id = nil, &block)
        if block_given? || @options[:finder_sql]
          load_collection_to_array
          return @collection_array.send(:find, &block)
        else
          @association_class.find_on_conditions(
              association_id, "#{@association_class_primary_key_name} = '#{@owner.id}' #{@conditions ? " AND " + @conditions : ""}"
            )
        end
      end
      
      protected
        def find_all_records
          if @options[:finder_sql]
            @association_class.find_by_sql(@finder_sql)
          else
            @association_class.find_all(@finder_sql, @options[:order] ? @options[:order] : nil)
          end
        end
        
        def count_records
          if has_cached_counter?
            @owner.send(:read_attribute, cached_counter_attribute_name)
          elsif @options[:finder_sql]
            @association_class.count_by_sql(@counter_sql)
          else
            @association_class.count(@counter_sql)
          end
        end
        
        def has_cached_counter?
          @owner.attribute_present?(cached_counter_attribute_name)
        end
        
        def cached_counter_attribute_name
          @association_name + "_count"
        end
    end
  end
end