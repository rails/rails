module ActiveRecord
  module Associations
    class AssociationProxy #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?|^proxy_respond_to\?|^proxy_extend|^send)/ }

      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @owner = owner
        @options = options
        @association_name = association_name
        @association_class = eval(association_class_name, nil, __FILE__, __LINE__)
        @association_class_primary_key_name = association_class_primary_key_name

        proxy_extend(options[:extend]) if options[:extend]

        reset
      end
      
      def reload
        reset
        load_target
      end

      def respond_to?(symbol, include_priv = false)
        proxy_respond_to?(symbol, include_priv) || (load_target && @target.respond_to?(symbol, include_priv))
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
      
      def target=(t)
        @target = t
        @loaded = true
      end
      
      protected
        def dependent?
          @options[:dependent] || false
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
          @association_class.send(:sanitize_sql, sql)
        end

        def extract_options_from_args!(args)
          @owner.send(:extract_options_from_args!, args)
        end
        
      private
        
        def method_missing(method, *args, &block)
          load_target
          @target.send(method, *args, &block)
        end

        def load_target
          if !@owner.new_record? || foreign_key_present
            begin
              @target = find_target if not loaded?
            rescue ActiveRecord::RecordNotFound
              reset
            end
          end
          @loaded = true if @target
          @target
        end

        # Can be overwritten by associations that might have the foreign key available for an association without
        # having the object itself (and still being a new record). Currently, only belongs_to present this scenario.
        def foreign_key_present
          false
        end

        def raise_on_type_mismatch(record)
          raise ActiveRecord::AssociationTypeMismatch, "#{@association_class} expected, got #{record.class}" unless record.is_a?(@association_class)
        end
    end
  end
end