module ActiveRecord
  module Associations
    class HasManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @conditions = @association_class.send(:sanitize_conditions, options[:conditions])

        if options[:finder_sql]
          @finder_sql = interpolate_sql(options[:finder_sql])
        else
          @finder_sql = "#{@association_class_primary_key_name} = '#{@owner.id}' #{@conditions ? " AND " + interpolate_sql(@conditions) : ""}"
        end

        if options[:counter_sql]
          @counter_sql = interpolate_sql(options[:counter_sql])
        elsif options[:finder_sql]
          @counter_sql = options[:counter_sql] = @finder_sql.gsub(/SELECT (.*) FROM/i, "SELECT COUNT(*) FROM")
        else
          @counter_sql = "#{@association_class_primary_key_name} = '#{@owner.id}'#{@conditions ? " AND " + interpolate_sql(@conditions) : ""}"
        end
      end

      def create(attributes = {})
        # Can't use Base.create since the foreign key may be a protected attribute.
        record = build(attributes)
        record.save
        @collection << record if loaded?
        record
      end

      def build(attributes = {})
        record = @association_class.new(attributes)
        record[@association_class_primary_key_name] = @owner.id
        record
      end

      def find_all(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil, &block)
        if block_given? || @options[:finder_sql]
          load_collection
          @collection.find_all(&block)
        else
          @association_class.find_all(
            "#{@association_class_primary_key_name} = '#{@owner.id}' " +
            "#{@conditions ? " AND " + @conditions : ""} #{runtime_conditions ? " AND " + @association_class.send(:sanitize_conditions, runtime_conditions) : ""}",
            orderings, 
            limit, 
            joins
          )
        end
      end

      def find(association_id = nil, &block)
        if block_given? || @options[:finder_sql]
          load_collection
          @collection.find(&block)
        else
          @association_class.find_on_conditions(association_id,
            "#{@association_class_primary_key_name} = '#{@owner.id}' #{@conditions ? " AND " + @conditions : ""}"
          )
        end
      end

      # Removes all records from this association.  Returns +self+ so
      # method calls may be chained.
      def clear
        @association_class.update_all("#{@association_class_primary_key_name} = NULL", "#{@association_class_primary_key_name} = '#{@owner.id}'")
        @collection = []
        self
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
          elsif @options[:counter_sql]
            @association_class.count_by_sql(@counter_sql)
          else
            @association_class.count(@counter_sql)
          end
        end

        def has_cached_counter?
          @owner.attribute_present?(cached_counter_attribute_name)
        end

        def cached_counter_attribute_name
          "#{@association_name}_count"
        end

        def insert_record(record)
          record.update_attribute(@association_class_primary_key_name, @owner.id)
        end

        def delete_records(records)
          ids = quoted_record_ids(records)
          @association_class.update_all("#{@association_class_primary_key_name} = NULL", "#{@association_class_primary_key_name} = '#{@owner.id}' AND #{@association_class.primary_key} IN (#{ids})")
        end
    end
  end
end
