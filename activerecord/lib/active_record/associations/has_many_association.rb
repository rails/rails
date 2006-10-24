module ActiveRecord
  module Associations
    class HasManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end

      def build(attributes = {})
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr) }
        else
          record = @reflection.klass.new(attributes)
          set_belongs_to_association_for(record)
          
          @target ||= [] unless loaded?
          @target << record
          
          record
        end
      end

      # DEPRECATED.
      def find_all(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil)
        if @reflection.options[:finder_sql]
          @reflection.klass.find_by_sql(@finder_sql)
        else
          conditions = @finder_sql
          conditions += " AND (#{sanitize_sql(runtime_conditions)})" if runtime_conditions
          orderings ||= @reflection.options[:order]
          @reflection.klass.find_all(conditions, orderings, limit, joins)
        end
      end
      deprecate :find_all => "use find(:all, ...) instead"

      # DEPRECATED. Find the first associated record.  All arguments are optional.
      def find_first(conditions = nil, orderings = nil)
        find_all(conditions, orderings, 1).first
      end
      deprecate :find_first => "use find(:first, ...) instead"

      # Count the number of associated records. All arguments are optional.
      def count(*args)
        if @reflection.options[:counter_sql]
          @reflection.klass.count_by_sql(@counter_sql)
        elsif @reflection.options[:finder_sql]
          @reflection.klass.count_by_sql(@finder_sql)
        else
          column_name, options = @reflection.klass.send(:construct_count_options_from_legacy_args, *args)          
          options[:conditions] = options[:conditions].nil? ?
            @finder_sql :
            @finder_sql + " AND (#{sanitize_sql(options[:conditions])})"
          options[:include] = @reflection.options[:include]

          @reflection.klass.count(column_name, options)
        end
      end

      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @reflection.options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |record| id == record.id }
            expects_array ? [ record ] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          conditions = "#{@finder_sql}"
          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end
          options[:conditions] = conditions

          if options[:order] && @reflection.options[:order]
            options[:order] = "#{options[:order]}, #{@reflection.options[:order]}"
          elsif @reflection.options[:order]
            options[:order] = @reflection.options[:order]
          end

          merge_options_from_reflection!(options)

          # Pass through args exactly as we received them.
          args << options
          @reflection.klass.find(*args)
        end
      end

      protected
        def method_missing(method, *args, &block)
          if @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            super
          else
            create_scoping = {}
            set_belongs_to_association_for(create_scoping)

            @reflection.klass.with_scope(
              :create => create_scoping,
              :find => {
                :conditions => @finder_sql, 
                :joins      => @join_sql, 
                :readonly   => false
              }
            ) do
              @reflection.klass.send(method, *args, &block)
            end
          end
        end

        def load_target
          if !@owner.new_record? || foreign_key_present
            begin
              if !loaded?
                if @target.is_a?(Array) && @target.any?
                  @target = (find_target + @target).uniq
                else
                  @target = find_target
                end
              end
            rescue ActiveRecord::RecordNotFound
              reset
            end
          end

          loaded if target
          target
        end

        def count_records
          count = if has_cached_counter?
            @owner.send(:read_attribute, cached_counter_attribute_name)
          elsif @reflection.options[:counter_sql]
            @reflection.klass.count_by_sql(@counter_sql)
          else
            @reflection.klass.count(:conditions => @counter_sql)
          end
          
          @target = [] and loaded if count == 0
          
          if @reflection.options[:limit]
            count = [ @reflection.options[:limit], count ].min
          end
          
          return count
        end

        def has_cached_counter?
          @owner.attribute_present?(cached_counter_attribute_name)
        end

        def cached_counter_attribute_name
          "#{@reflection.name}_count"
        end

        def insert_record(record)
          set_belongs_to_association_for(record)
          record.save
        end

        def delete_records(records)
          if @reflection.options[:dependent]
            records.each { |r| r.destroy }
          else
            ids = quoted_record_ids(records)
            @reflection.klass.update_all(
              "#{@reflection.primary_key_name} = NULL", 
              "#{@reflection.primary_key_name} = #{@owner.quoted_id} AND #{@reflection.klass.primary_key} IN (#{ids})"
            )
          end
        end

        def target_obsolete?
          false
        end

        def construct_sql
          case
            when @reflection.options[:finder_sql]
              @finder_sql = interpolate_sql(@reflection.options[:finder_sql])

            when @reflection.options[:as]
              @finder_sql = 
                "#{@reflection.klass.table_name}.#{@reflection.options[:as]}_id = #{@owner.quoted_id} AND " + 
                "#{@reflection.klass.table_name}.#{@reflection.options[:as]}_type = #{@owner.class.quote_value(@owner.class.base_class.name.to_s)}"
              @finder_sql << " AND (#{conditions})" if conditions
            
            else
              @finder_sql = "#{@reflection.klass.table_name}.#{@reflection.primary_key_name} = #{@owner.quoted_id}"
              @finder_sql << " AND (#{conditions})" if conditions
          end

          if @reflection.options[:counter_sql]
            @counter_sql = interpolate_sql(@reflection.options[:counter_sql])
          elsif @reflection.options[:finder_sql]
            # replace the SELECT clause with COUNT(*), preserving any hints within /* ... */
            @reflection.options[:counter_sql] = @reflection.options[:finder_sql].sub(/SELECT (\/\*.*?\*\/ )?(.*)\bFROM\b/im) { "SELECT #{$1}COUNT(*) FROM" }
            @counter_sql = interpolate_sql(@reflection.options[:counter_sql])
          else
            @counter_sql = @finder_sql
          end
        end
    end
  end
end
