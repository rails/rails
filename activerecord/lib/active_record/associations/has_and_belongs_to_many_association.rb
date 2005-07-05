module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super

        @association_foreign_key = options[:association_foreign_key] || Inflector.underscore(Inflector.demodulize(association_class_name)) + "_id"
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

      # Removes all records from this association.  Returns +self+ so method calls may be chained.
      def clear
        return self if size == 0 # forces load_target if hasn't happened already

        if sql = @options[:delete_sql]
          each { |record| @owner.connection.execute(sql) }
        elsif @options[:conditions] 
          sql = 
            "DELETE FROM #{@join_table} WHERE #{@association_class_primary_key_name} = #{@owner.quoted_id} " +
            "AND #{@association_foreign_key} IN (#{collect { |record| record.id }.join(", ")})"
          @owner.connection.execute(sql)
        else
          sql = "DELETE FROM #{@join_table} WHERE #{@association_class_primary_key_name} = #{@owner.quoted_id}"
          @owner.connection.execute(sql)
        end

        @target = []
        self
      end

      def find_first
        load_target.first
      end

      def find(*args)
        # Return an Array if multiple ids are given.
        expects_array = args.first.kind_of?(Array)

        ids = args.flatten.compact.uniq

        # If no block is given, raise RecordNotFound.
        if ids.empty?
          raise RecordNotFound, "Couldn't find #{@association_class.name} without an ID"

        # If using a custom finder_sql, scan the entire collection.
        elsif @options[:finder_sql]
          if ids.size == 1
            id = ids.first
            record = load_target.detect { |record| id == record.id }
            expects_array? ? [record] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end

        # Otherwise, construct a query.
        else
          ids_list = ids.map { |id| @owner.send(:quote, id) }.join(',')
          records = find_target(@finder_sql.sub(/(ORDER BY|$)/, " AND j.#{@association_foreign_key} IN (#{ids_list}) \\1"))
          if records.size == ids.size
            if ids.size == 1 and !expects_array
              records.first
            else
              records
            end
          else
            raise RecordNotFound, "Couldn't find #{@association_class.name} with ID in (#{ids_list})"
          end
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
        def find_target(sql = @finder_sql)
          records = @association_class.find_by_sql(sql)
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
                  value = record[column.name]
                  attributes[column.name] = value unless value.nil?
              end
              attributes
            end

            sql =
              "INSERT INTO #{@join_table} (#{@owner.send(:quoted_column_names, attributes).join(', ')}) " +
              "VALUES (#{attributes.values.collect { |value| @owner.send(:quote, value) }.join(', ')})"

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
            @finder_sql = 
              "SELECT t.*, j.* FROM #{@join_table} j, #{@association_table_name} t " +
              "WHERE t.#{@association_class.primary_key} = j.#{@association_foreign_key} AND " +
              "j.#{@association_class_primary_key_name} = #{@owner.quoted_id} "
            
            @finder_sql << " AND #{interpolate_sql(@options[:conditions])}" if @options[:conditions]

            unless @association_class.descends_from_active_record?
              type_condition = @association_class.send(:subclasses).inject("t.#{@association_class.inheritance_column} = '#{@association_class.name.demodulize}' ") do |condition, subclass| 
                condition << "OR t.#{@association_class.inheritance_column} = '#{subclass.name.demodulize}' "
              end

              @finder_sql << " AND (#{type_condition})"
            end
	
            @finder_sql << " ORDER BY #{@order}" if @order
          end
        end
    end
  end
end
