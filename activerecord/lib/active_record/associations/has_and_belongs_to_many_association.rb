module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super

        @association_foreign_key = options[:association_foreign_key] || association_class_name.foreign_key
        @association_table_name = options[:table_name] || @association_class.table_name
        @join_table = options[:join_table]
        @order = options[:order]

        construct_sql
      end
 
      def build(attributes = {})
        load_target
        record = @association_class.new(attributes)
        @target << record
        record
      end

      def find_first
        load_target.first
      end
      
      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first.to_i
            record = load_target.detect { |record| id == record.id }
            expects_array ? [record] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          conditions = "#{@finder_sql}"
          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end
          options[:conditions] = conditions
          options[:joins] = @join_sql
          options[:readonly] ||= false

          if options[:order] && @options[:order]
            options[:order] = "#{options[:order]}, #{@options[:order]}"
          elsif @options[:order]
            options[:order] = @options[:order]
          end

          # Pass through args exactly as we received them.
          args << options
          @association_class.find(*args)
        end
      end      

      def push_with_attributes(record, join_attributes = {})
        raise_on_type_mismatch(record)
        join_attributes.each { |key, value| record[key.to_s] = value }
        callback(:before_add, record)
        insert_record(record) unless @owner.new_record?
        @target << record
        callback(:after_add, record)
        self
      end
      
      alias :concat_with_attributes :push_with_attributes

      def size
        @options[:uniq] ? count_records : super
      end
      
      protected
        def method_missing(method, *args, &block)
          if @target.respond_to?(method) || (!@association_class.respond_to?(method) && Class.respond_to?(method))
            super
          else
            @association_class.with_scope(:find => { :conditions => @finder_sql, :joins => @join_sql, :readonly => false }) do
              @association_class.send(method, *args, &block)
            end
          end
        end
            
        def find_target
          if @options[:finder_sql]
            records = @association_class.find_by_sql(@finder_sql)
          else
            records = find(:all, :include => @options[:include])
          end
          
          @options[:uniq] ? uniq(records) : records
        end
        
        def count_records
          load_target.size
        end

        def insert_record(record)
          if record.new_record?
            return false unless record.save
          end

          if @options[:insert_sql]
            @owner.connection.execute(interpolate_sql(@options[:insert_sql], record))
          else
            columns = @owner.connection.columns(@join_table, "#{@join_table} Columns")

            attributes = columns.inject({}) do |attributes, column|
              case column.name
                when @association_class_primary_key_name
                  attributes[column.name] = @owner.quoted_id
                when @association_foreign_key
                  attributes[column.name] = record.quoted_id
                else
                  if record.attributes.has_key?(column.name)
                    value = @owner.send(:quote, record[column.name], column)
                    attributes[column.name] = value unless value.nil?
                  end
              end
              attributes
            end

            sql =
              "INSERT INTO #{@join_table} (#{@owner.send(:quoted_column_names, attributes).join(', ')}) " +
              "VALUES (#{attributes.values.join(', ')})"

            @owner.connection.execute(sql)
          end
          
          return true
        end
        
        def delete_records(records)
          if sql = @options[:delete_sql]
            records.each { |record| @owner.connection.execute(interpolate_sql(sql, record)) }
          else
            ids = quoted_record_ids(records)
            sql = "DELETE FROM #{@join_table} WHERE #{@association_class_primary_key_name} = #{@owner.quoted_id} AND #{@association_foreign_key} IN (#{ids})"
            @owner.connection.execute(sql)
          end
        end

        def construct_sql
          interpolate_sql_options!(@options, :finder_sql)

          if @options[:finder_sql]
            @finder_sql = @options[:finder_sql]
          else
            @finder_sql = "#{@join_table}.#{@association_class_primary_key_name} = #{@owner.quoted_id} "
            @finder_sql << " AND (#{interpolate_sql(@options[:conditions])})" if @options[:conditions]
          end
          
          @join_sql = "LEFT JOIN #{@join_table} ON #{@association_class.table_name}.#{@association_class.primary_key} = #{@join_table}.#{@association_foreign_key}"
        end
        
    end
  end
end
