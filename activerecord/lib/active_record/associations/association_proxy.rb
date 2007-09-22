module ActiveRecord
  module Associations
    class AssociationProxy #:nodoc:
      attr_reader :reflection
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
      delegate :to_param, :to => :proxy_target
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_)/ }

      def initialize(owner, reflection)
        @owner, @reflection = owner, reflection
        Array(reflection.options[:extend]).each { |ext| proxy_extend(ext) }
        reset
      end
      
      def proxy_owner
        @owner
      end
      
      def proxy_reflection
        @reflection
      end
      
      def proxy_target
        @target
      end

      def respond_to?(symbol, include_priv = false)
        proxy_respond_to?(symbol, include_priv) || (load_target && @target.respond_to?(symbol, include_priv))
      end
      
      # Explicitly proxy === because the instance method removal above
      # doesn't catch it.
      def ===(other)
        load_target
        other === @target
      end
      
      def aliased_table_name
        @reflection.klass.table_name
      end
      
      def conditions
        @conditions ||= interpolate_sql(sanitize_sql(@reflection.options[:conditions])) if @reflection.options[:conditions]
      end
      alias :sql_conditions :conditions
      
      def reset
        @target = nil
        @loaded = false
      end

      def reload
        reset
        load_target
      end

      def loaded?
        @loaded
      end
      
      def loaded
        @loaded = true
      end
      
      def target
        @target
      end
      
      def target=(target)
        @target = target
        loaded
      end
      
      def inspect
        reload unless loaded?
        @target.inspect
      end

      protected
        def dependent?
          @reflection.options[:dependent]
        end
        
        def quoted_record_ids(records)
          records.map { |record| record.quoted_id }.join(',')
        end

        def interpolate_sql_options!(options, *keys)
          keys.each { |key| options[key] &&= interpolate_sql(options[key]) }
        end

        def interpolate_sql(sql, record = nil)
          @owner.send(:interpolate_sql, sql, record)
        end

        def sanitize_sql(sql)
          @reflection.klass.send(:sanitize_sql, sql)
        end

        def set_belongs_to_association_for(record)
          if @reflection.options[:as]
            record["#{@reflection.options[:as]}_id"]   = @owner.id unless @owner.new_record?
            record["#{@reflection.options[:as]}_type"] = @owner.class.base_class.name.to_s
          else
            record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
          end
        end

        def merge_options_from_reflection!(options)
          options.reverse_merge!(
            :group   => @reflection.options[:group],
            :limit   => @reflection.options[:limit],
            :offset  => @reflection.options[:offset],
            :joins   => @reflection.options[:joins],
            :include => @reflection.options[:include],
            :select  => @reflection.options[:select]
          )
        end
        
      private
        def method_missing(method, *args, &block)
          if load_target        
            @target.send(method, *args, &block)
          end
        end

        def load_target
          return nil unless defined?(@loaded)

          if !loaded? and (!@owner.new_record? || foreign_key_present)
            @target = find_target
          end

          @loaded = true
          @target
        rescue ActiveRecord::RecordNotFound
          reset
        end

        # Can be overwritten by associations that might have the foreign key available for an association without
        # having the object itself (and still being a new record). Currently, only belongs_to presents this scenario.
        def foreign_key_present
          false
        end

        def raise_on_type_mismatch(record)
          unless record.is_a?(@reflection.klass)
            raise ActiveRecord::AssociationTypeMismatch, "#{@reflection.klass} expected, got #{record.class}"
          end
        end

        # Array#flatten has problems with recursive arrays. Going one level deeper solves the majority of the problems.
        def flatten_deeper(array)
          array.collect { |element| element.respond_to?(:flatten) ? element.flatten : element }.flatten
        end
    end
  end
end
