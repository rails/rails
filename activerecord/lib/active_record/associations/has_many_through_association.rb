module ActiveRecord
  module Associations
    class HasManyThroughAssociation < AssociationProxy #:nodoc:

      def initialize(owner, reflection)
        super
        @finder_sql = construct_conditions
        construct_sql
      end


      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

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
        
        options[:select] = construct_select
        options[:from]   = construct_from
        
        merge_options_from_reflection!(options)

        # Pass through args exactly as we received them.
        args << options
        @reflection.klass.find(*args)
      end

      def reset
        @target = []
        @loaded = false
      end

      protected
        def through_reflection
          unless @through_reflection ||= @owner.class.reflections[@reflection.options[:through]]
            raise ActiveRecordError, "Could not find the association '#{@reflection.options[:through]}' in model #{@reflection.klass}"
          end
          @through_reflection
        end

        def source_reflection
          @source_reflection_name ||= @reflection.name.to_s.singularize.to_sym
          unless @source_reflection ||= through_reflection.klass.reflect_on_association(@source_reflection_name)
            raise ActiveRecordError, "Could not find the source association '#{@source_reflection_name}' in model #{@through_reflection.klass}"
          end
          @source_reflection
        end

        def method_missing(method, *args, &block)
          if @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            super
          else
            @reflection.klass.with_scope(construct_scope) { @reflection.klass.send(method, *args, &block) }
          end
        end
            
        def find_target
          @reflection.klass.find(:all, 
            :select     => construct_select,
            :conditions => construct_conditions,
            :from       => construct_from,
            :order      => @reflection.options[:order], 
            :limit      => @reflection.options[:limit],
            :joins      => @reflection.options[:joins],
            :group      => @reflection.options[:group]
          )
        end

        def construct_conditions
          # Get the actual primary key of the belongs_to association that the reflection is going through
          source_primary_key = source_reflection.primary_key_name
          
          if through_reflection.options[:as]
            conditions = 
              "#{@reflection.table_name}.#{@reflection.klass.primary_key} = #{through_reflection.table_name}.#{source_primary_key} " +
              "AND #{through_reflection.table_name}.#{through_reflection.options[:as]}_id = #{@owner.quoted_id} " + 
              "AND #{through_reflection.table_name}.#{through_reflection.options[:as]}_type = #{@owner.class.quote @owner.class.base_class.name.to_s}"
          else
            conditions = 
              "#{@reflection.klass.table_name}.#{@reflection.klass.primary_key} = #{through_reflection.table_name}.#{source_primary_key} " +
              "AND #{through_reflection.table_name}.#{through_reflection.primary_key_name} = #{@owner.quoted_id}"
          end
          
          conditions << " AND (#{sql_conditions})" if sql_conditions
          
          return conditions
        end

        def construct_from
          "#{@owner.class.reflections[@reflection.options[:through]].table_name}, #{@reflection.table_name}"
        end
        
        def construct_select
          selected = @reflection.options[:select] || "#{@reflection.table_name}.*"          
        end
        
        def construct_scope
          {
            :find   => { :from => construct_from, :conditions => construct_conditions },
            :create => { @reflection.primary_key_name => @owner.id }
          }
        end
        
        def construct_sql
          case
            when @reflection.options[:finder_sql]
              @finder_sql = interpolate_sql(@reflection.options[:finder_sql])

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
        
        def sql_conditions
          @conditions ||= interpolate_sql(@reflection.active_record.send(:sanitize_sql, through_reflection.options[:conditions])) if through_reflection.options[:conditions]
        end
    end
  end
end
