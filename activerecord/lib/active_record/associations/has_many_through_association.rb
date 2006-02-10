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
          through_reflection = @owner.class.reflections[@reflection.options[:through]]
          
          if through_reflection.options[:as]
            conditions = 
              "#{@reflection.table_name}.#{@reflection.klass.primary_key} = #{through_reflection.table_name}.#{@reflection.klass.to_s.foreign_key} " +
              "AND #{through_reflection.table_name}.#{through_reflection.options[:as]}_id = #{@owner.quoted_id} " + 
              "AND #{through_reflection.table_name}.#{through_reflection.options[:as]}_type = '#{ActiveRecord::Base.send(:class_name_of_active_record_descendant, @owner.class).to_s}'"
          else
            conditions = 
              "#{@reflection.klass.table_name}.#{@reflection.klass.primary_key} = #{through_reflection.table_name}.#{@reflection.klass.to_s.foreign_key} " +
              "AND #{through_reflection.table_name}.#{through_reflection.primary_key_name} = #{@owner.quoted_id}"
          end
          
          conditions << " AND (#{interpolate_sql(sanitize_sql(@reflection.options[:conditions]))})" if @reflection.options[:conditions]
          
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
              @finder_sql << " AND (#{interpolate_sql(@conditions)})" if @conditions
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
