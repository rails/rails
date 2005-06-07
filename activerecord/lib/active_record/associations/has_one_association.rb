module ActiveRecord
  module Associations
    class HasOneAssociation < BelongsToAssociation #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super

        construct_sql
      end

      def create(attributes = {}, replace_existing = true)
        record = build(attributes, replace_existing)
        record.save
        record
      end

      def build(attributes = {}, replace_existing = true)
        record = @association_class.new(attributes)

        if replace_existing
          replace(record, true) 
        else
          record[@association_class_primary_key_name] = @owner.id unless @owner.new_record?
          self.target = record
        end

        record
      end

      def replace(obj, dont_save = false)
        load_target
        unless @target.nil?
          if dependent? && !dont_save     
            @target.destroy unless @target.new_record?
            @owner.clear_association_cache
          else
            @target[@association_class_primary_key_name] = nil
            @target.save unless @owner.new_record?
          end
        end

        if obj.nil?
          @target = nil
        else
          raise_on_type_mismatch(obj)
          
          obj[@association_class_primary_key_name] = @owner.id unless @owner.new_record?
          @target = obj
        end

        @loaded = true
        unless @owner.new_record? or obj.nil? or dont_save
          return (obj.save ? self : false)
        else
          return (obj.nil? ? nil : self)
        end
      end
      
      private
        def find_target
          @association_class.find(:first, :conditions => @finder_sql, :order => @options[:order])
        end

        def target_obsolete?
          false
        end

        def construct_sql
          @finder_sql = "#{@association_class.table_name}.#{@association_class_primary_key_name} = #{@owner.quoted_id}#{@options[:conditions] ? " AND " + @options[:conditions] : ""}"
        end
    end
  end
end
