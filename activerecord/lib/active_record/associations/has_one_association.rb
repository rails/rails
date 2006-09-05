module ActiveRecord
  module Associations
    class HasOneAssociation < BelongsToAssociation #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end

      def create(attributes = {}, replace_existing = true)
        record = build(attributes, replace_existing)
        record.save
        record
      end

      def build(attributes = {}, replace_existing = true)
        record = @reflection.klass.new(attributes)

        if replace_existing
          replace(record, true) 
        else
          record[@reflection.primary_key_name] = @owner.id unless @owner.new_record?
          self.target = record
        end

        record
      end

      def replace(obj, dont_save = false)
        load_target

        unless @target.nil?
          if dependent? && !dont_save && @target != obj
            @target.destroy unless @target.new_record?
            @owner.clear_association_cache
          else
            @target[@reflection.primary_key_name] = nil
            @target.save unless @owner.new_record? || @target.new_record?
          end
        end

        if obj.nil?
          @target = nil
        else
          raise_on_type_mismatch(obj)
          set_belongs_to_association_for(obj)
          @target = (AssociationProxy === obj ? obj.target : obj)
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
          @reflection.klass.find(:first, 
            :conditions => @finder_sql, 
            :order      => @reflection.options[:order], 
            :include    => @reflection.options[:include]
          )
        end

        def construct_sql
          case
            when @reflection.options[:as]
              @finder_sql = 
                "#{@reflection.klass.table_name}.#{@reflection.options[:as]}_id = #{@owner.quoted_id} AND " + 
                "#{@reflection.klass.table_name}.#{@reflection.options[:as]}_type = #{@owner.class.quote_value(@owner.class.base_class.name.to_s)}"          
            else
              @finder_sql = "#{@reflection.table_name}.#{@reflection.primary_key_name} = #{@owner.quoted_id}"
          end
          @finder_sql << " AND (#{conditions})" if conditions
        end
    end
  end
end
