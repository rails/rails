module ActiveRecord
  module Associations
    class HasManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super
        @conditions = sanitize_sql(options[:conditions])

        construct_sql
      end

      def build(attributes = {})
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr) }
        else
          load_target
          record = @association_class.new(attributes)
          record[@association_class_primary_key_name] = @owner.id unless @owner.new_record?
          @target << record
          record
        end
      end

      # DEPRECATED.
      def find_all(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil)
        if @options[:finder_sql]
          @association_class.find_by_sql(@finder_sql)
        else
          conditions = @finder_sql
          conditions += " AND (#{sanitize_sql(runtime_conditions)})" if runtime_conditions
          orderings ||= @options[:order]
          @association_class.find_all(conditions, orderings, limit, joins)
        end
      end

      # DEPRECATED. Find the first associated record.  All arguments are optional.
      def find_first(conditions = nil, orderings = nil)
        find_all(conditions, orderings, 1).first
      end

      # Count the number of associated records. All arguments are optional.
      def count(runtime_conditions = nil)
        if @options[:counter_sql]
          @association_class.count_by_sql(@counter_sql)
        elsif @options[:finder_sql]
          @association_class.count_by_sql(@finder_sql)
        else
          sql = @finder_sql
          sql += " AND (#{sanitize_sql(runtime_conditions)})" if runtime_conditions
          @association_class.count(sql)
        end
      end

      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |record| id == record.id }
            expects_array? ? [record] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          conditions = "#{@finder_sql}"
          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end
          options[:conditions] = conditions

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
      
      protected
        def method_missing(method, *args, &block)
          if @target.respond_to?(method) || (!@association_class.respond_to?(method) && Class.respond_to?(method))
            super
          else
            @association_class.with_scope(
              :find => {
                :conditions => @finder_sql, 
                :joins      => @join_sql, 
                :readonly   => false
              },
              :create => {
                @association_class_primary_key_name => @owner.id
              }
            ) do
              @association_class.send(method, *args, &block)
            end
          end
        end
            
        def find_target
          if @options[:finder_sql]
            @association_class.find_by_sql(@finder_sql)
          else
            @association_class.find(:all, 
              :conditions => @finder_sql,
              :order      => @options[:order], 
              :limit      => @options[:limit],
              :joins      => @options[:joins],
              :include    => @options[:include],
              :group      => @options[:group]
            )
          end
        end

        def count_records
          count = if has_cached_counter?
            @owner.send(:read_attribute, cached_counter_attribute_name)
          elsif @options[:counter_sql]
            @association_class.count_by_sql(@counter_sql)
          else
            @association_class.count(@counter_sql)
          end
          
          @target = [] and loaded if count == 0
          
          return count
        end

        def has_cached_counter?
          @owner.attribute_present?(cached_counter_attribute_name)
        end

        def cached_counter_attribute_name
          "#{@association_name}_count"
        end

        def insert_record(record)
          record[@association_class_primary_key_name] = @owner.id
          record.save
        end

        def delete_records(records)
          if @options[:dependent]
            records.each { |r| r.destroy }
          else
            ids = quoted_record_ids(records)
            @association_class.update_all(
              "#{@association_class_primary_key_name} = NULL", 
              "#{@association_class_primary_key_name} = #{@owner.quoted_id} AND #{@association_class.primary_key} IN (#{ids})"
            )
          end
        end

        def target_obsolete?
          false
        end

        def construct_sql
          if @options[:finder_sql]
            @finder_sql = interpolate_sql(@options[:finder_sql])
          else
            @finder_sql = "#{@association_class.table_name}.#{@association_class_primary_key_name} = #{@owner.quoted_id}"
            @finder_sql << " AND (#{interpolate_sql(@conditions)})" if @conditions
          end

          if @options[:counter_sql]
            @counter_sql = interpolate_sql(@options[:counter_sql])
          elsif @options[:finder_sql]
            @options[:counter_sql] = @options[:finder_sql].gsub(/SELECT (.*) FROM/i, "SELECT COUNT(*) FROM")
            @counter_sql = interpolate_sql(@options[:counter_sql])
          else
            @counter_sql = "#{@association_class.table_name}.#{@association_class_primary_key_name} = #{@owner.quoted_id}"
            @counter_sql << " AND (#{interpolate_sql(@conditions)})" if @conditions
          end
        end
    end
  end
end
