module ActiveRecord
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super        
        construct_sql        
      end
      
      def reset
        @target = nil
        @loaded = false
      end

      def create(attributes = {})
        record = @association_class.create(attributes)
        replace(record, true)
        record
      end

      def build(attributes = {})
        record = @association_class.new(attributes)
        replace(record, true)
        record
      end

      def replace(obj, dont_save = false)
        if obj.nil?
          @target = @owner[@association_class_primary_key_name] = nil
        else
          raise_on_type_mismatch(obj) unless obj.nil?

          @target = (AssociationProxy === obj ? obj.target : obj)
          @owner[@association_class_primary_key_name] = obj.id unless obj.new_record?
          @updated = true
        end
        @loaded = true

        return (@target.nil? ? nil : self)
      end
      
      def updated?
        @updated
      end
      
      protected


      private
        def find_target
          if @options[:conditions]
            @association_class.find(
              @owner[@association_class_primary_key_name], 
              :conditions => interpolate_sql(@options[:conditions]),
              :include    => @options[:include]
            )
          else
            @association_class.find(@owner[@association_class_primary_key_name], :include => @options[:include])
          end
        end

        def foreign_key_present
          !@owner[@association_class_primary_key_name].nil?
        end

        def target_obsolete?
          @owner[@association_class_primary_key_name] != @target.id
        end
        
        def construct_sql
          @finder_sql = "#{@association_class.table_name}.#{@association_class.primary_key} = #{@owner.id}"
        end
    end
  end
end
