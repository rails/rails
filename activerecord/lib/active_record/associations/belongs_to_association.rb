module ActiveRecord
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      def reset
        @target = nil
        @loaded = false
      end

      def create(attributes = {})
        record = build(attributes)
        record.save
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

          @target = obj
          @owner[@association_class_primary_key_name] = obj.id unless obj.new_record?
        end
        @loaded = true

        return (@target.nil? ? nil : self)
      end

      private
        def find_target
          if @options[:conditions]
            @association_class.find_on_conditions(@owner[@association_class_primary_key_name], interpolate_sql(@options[:conditions]))
          else
            @association_class.find(@owner[@association_class_primary_key_name])
          end
        end

        def foreign_key_present
          !@owner[@association_class_primary_key_name].nil?
        end

        def target_obsolete?
          @owner[@association_class_primary_key_name] != @target.id
        end

        def construct_sql
          # no sql to construct
        end
    end
  end
end
