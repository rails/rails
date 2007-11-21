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
          build_record(attributes) { |record| set_belongs_to_association_for(record) }
        end
      end

      # Count the number of associated records. All arguments are optional.
      def count(*args)
        if @reflection.options[:counter_sql]
          @reflection.klass.count_by_sql(@counter_sql)
        elsif @reflection.options[:finder_sql]
          @reflection.klass.count_by_sql(@finder_sql)
        else
          column_name, options = @reflection.klass.send(:construct_count_options_from_args, *args)          
          options[:conditions] = options[:conditions].nil? ?
            @finder_sql :
            @finder_sql + " AND (#{sanitize_sql(options[:conditions])})"
          options[:include] ||= @reflection.options[:include]

          @reflection.klass.count(column_name, options)
        end
      end

      def find(*args)
        options = args.extract_options!

        # If using a custom finder_sql, scan the entire collection.
        if @reflection.options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids           = args.flatten.compact.uniq.map(&:to_i)

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
            @reflection.klass.count(:conditions => @counter_sql, :include => @reflection.options[:include])
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
          case @reflection.options[:dependent]
            when :destroy
              records.each(&:destroy)
            when :delete_all
              @reflection.klass.delete(records.map(&:id))
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

        def construct_scope
          create_scoping = {}
          set_belongs_to_association_for(create_scoping)
          { :find => { :conditions => @finder_sql, :readonly => false, :order => @reflection.options[:order], :limit => @reflection.options[:limit] }, :create => create_scoping }
        end
    end
  end
end
