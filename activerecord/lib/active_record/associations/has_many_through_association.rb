module ActiveRecord
  module Associations
    class HasManyThroughAssociation < AssociationProxy #:nodoc:
      def initialize(owner, reflection)
        super
        reflection.check_validity!
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
        
        options[:select]  = construct_select(options[:select])
        options[:from]  ||= construct_from
        options[:joins]   = construct_joins(options[:joins])
        options[:include] = @reflection.source_reflection.options[:include] if options[:include].nil?
        
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
            :joins      => construct_joins,
            :order      => @reflection.options[:order], 
            :limit      => @reflection.options[:limit],
            :group      => @reflection.options[:group],
            :include    => @reflection.options[:include] || @reflection.source_reflection.options[:include]
          )
        end

        def construct_conditions
          conditions = if @reflection.through_reflection.options[:as]
              "#{@reflection.through_reflection.table_name}.#{@reflection.through_reflection.options[:as]}_id = #{@owner.quoted_id} " + 
              "AND #{@reflection.through_reflection.table_name}.#{@reflection.through_reflection.options[:as]}_type = #{@owner.class.quote @owner.class.base_class.name.to_s}"
          else
            "#{@reflection.through_reflection.table_name}.#{@reflection.through_reflection.primary_key_name} = #{@owner.quoted_id}"
          end
          conditions << " AND (#{sql_conditions})" if sql_conditions
          
          return conditions
        end

        def construct_from
          @reflection.table_name
        end
        
        def construct_select(custom_select = nil)
          selected = custom_select || @reflection.options[:select] || "#{@reflection.table_name}.*"          
        end
        
        def construct_joins(custom_joins = nil)          
          polymorphic_join = nil
          if @reflection.through_reflection.options[:as] || @reflection.source_reflection.macro == :belongs_to
            reflection_primary_key = @reflection.klass.primary_key
            source_primary_key     = @reflection.source_reflection.primary_key_name
          else
            reflection_primary_key = @reflection.source_reflection.primary_key_name
            source_primary_key     = @reflection.klass.primary_key
            if @reflection.source_reflection.options[:as]
              polymorphic_join = "AND %s.%s = %s" % [
                @reflection.table_name, "#{@reflection.source_reflection.options[:as]}_type",
                @owner.class.quote(@reflection.through_reflection.klass.name)
              ]
            end
          end

          "INNER JOIN %s ON %s.%s = %s.%s %s #{@reflection.options[:joins]} #{custom_joins}" % [
            @reflection.through_reflection.table_name,
            @reflection.table_name, reflection_primary_key,
            @reflection.through_reflection.table_name, source_primary_key,
            polymorphic_join
          ]
        end
        
        def construct_scope
          {
            :find   => { :from => construct_from, :conditions => construct_conditions, :joins => construct_joins, :select => construct_select },
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
        
        def conditions
          @conditions ||= [
            (interpolate_sql(@reflection.active_record.send(:sanitize_sql, @reflection.options[:conditions])) if @reflection.options[:conditions]),
            (interpolate_sql(@reflection.active_record.send(:sanitize_sql, @reflection.through_reflection.options[:conditions])) if @reflection.through_reflection.options[:conditions])
          ].compact.collect { |condition| "(#{condition})" }.join(' AND ') unless (!@reflection.options[:conditions] && !@reflection.through_reflection.options[:conditions])
        end
        
        alias_method :sql_conditions, :conditions
    end
  end
end
