module ActiveRecord
  module Associations
    class HasOneAssociation < BelongsToAssociation #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        super

        construct_sql
      end

      def replace(obj, dont_save = false)
        load_target
        unless @target.nil?
          @target[@association_class_primary_key_name] = nil
          @target.save unless @owner.new_record?
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
          @association_class.find_first(@finder_sql, @options[:order])
        end

        def target_obsolete?
          false
        end

        def construct_sql
          @finder_sql = "#{@association_class_primary_key_name} = #{@owner.quoted_id}#{@options[:conditions] ? " AND " + @options[:conditions] : ""}"
        end
    end
  end
end
